using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

public class ChinesePaintingOutLine : ScriptableRendererFeature
{
    [System.Serializable]
    public class BlitSettings
    {
        public RenderPassEvent Event = RenderPassEvent.AfterRenderingOpaques;
        public Shader Shader = null;
        public float scale = 1;
        public float depthThreshold = 0.2f;
        [Range(0, 1)]
        public float normalThreshold = 0.4f;
        [Range(0, 1)]
        public float depthNormalThreshold = 0.5f;
        public float depthNormalThresholdScale = 7;
        public Color color = Color.white;
        [Range(0, 10)]
        public float noiseTiling = 2f;
        [Range(0, 1)]
        public float outLineWidth = 0.2f;
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

        private RenderTargetIdentifier source { get; set; }
        private RenderTargetIdentifier dest { get; set; }
        
        private RenderTargetHandle tempColorTex;

        private string profilerTag;

        public BlitPass(BlitSettings settings, string tag)
        {
            this.renderPassEvent = settings.Event;
            this.settings = settings;
            this.material = CoreUtils.CreateEngineMaterial(settings.Shader);
            this.profilerTag = tag;
        }

        public void Setup(ScriptableRenderer renderer)
        {
            ConfigureInput(ScriptableRenderPassInput.Normal);
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
            var renderer = renderingData.cameraData.renderer;
            source = renderer.cameraColorTarget;
            dest = renderer.cameraColorTarget;
            
            Render(cmd, renderingData);
            context.ExecuteCommandBuffer(cmd);
            CommandBufferPool.Release(cmd);
        }

        private void Render(CommandBuffer cmd, RenderingData renderingData)
        {
            RenderTextureDescriptor opaqueDesc = renderingData.cameraData.cameraTargetDescriptor;
            opaqueDesc.depthBufferBits = 0;
            cmd.GetTemporaryRT(tempColorTex.id, opaqueDesc);
            cmd.SetGlobalTexture(mainTexId, source);

            material.SetFloat("_Scale", settings.scale);
            material.SetFloat("_DepthThreshold", settings.depthThreshold);
            material.SetFloat("_NormalThreshold", settings.normalThreshold);
            Matrix4x4 clipToView = GL.GetGPUProjectionMatrix(renderingData.cameraData.GetGPUProjectionMatrix(), true);
            material.SetMatrix("_ClipToView", clipToView);
            material.SetFloat("_DepthNormalThreshold", settings.depthNormalThreshold);
            material.SetFloat("_DepthNormalThresholdScale", settings.depthNormalThresholdScale);
            material.SetColor("_EdgeColor", settings.color);
            material.SetFloat("_NoiseTiling", settings.noiseTiling);
            material.SetFloat("_OutLineWidth", settings.outLineWidth);

            cmd.Blit(source, tempColorTex.Identifier(), material);
            cmd.Blit(tempColorTex.Identifier(), dest);
        }
    }
}
