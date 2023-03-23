using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

public class SSAOPostProcessing : ScriptableRendererFeature
{
    [System.Serializable]
    public class BlitSettings
    {
        public RenderPassEvent Event = RenderPassEvent.AfterRenderingOpaques;
        public Shader Shader = null;
        public int blitMaterialPassIndex = 0;

        [Range(0, 128)]
        public int SampleCount = 8;
        [Range(0f, 0.8f)]
        public float Radius = 0.5f;
        [Range(0f, 1f)]
        public float EdgeCheck = 0.5f;
        [Range(0f, 10f)]
        public float aoInt = 1f;
        [Range(1f, 4f)]
        public float BlurRadius = 2f;
        [Range(0, 0.2f)]
        public float BilaterFilterStrength = 0.2f;
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
        var passIndex = Settings.Shader.passCount - 1;
        Settings.blitMaterialPassIndex = Mathf.Clamp(Settings.blitMaterialPassIndex, -1, passIndex);
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

        private RenderTargetHandle AO_Tex;

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
            cmd.GetTemporaryRT(AO_Tex.id, opaqueDesc);
            cmd.SetGlobalTexture(mainTexId, source);
            
            Matrix4x4 vp_Matrix = renderingData.cameraData.camera.projectionMatrix * renderingData.cameraData.camera.worldToCameraMatrix; 
            material.SetMatrix("_invVPMatrix", vp_Matrix.inverse);
            material.SetMatrix("_worldToCameraMatrix", renderingData.cameraData.camera.worldToCameraMatrix);
            material.SetMatrix("_projectionMatrix", renderingData.cameraData.camera.projectionMatrix);
            material.SetInt("_SampleCount", settings.SampleCount);
            material.SetFloat("_Radius", settings.Radius);
            material.SetFloat("_edgeCheck", settings.EdgeCheck);
            material.SetFloat("_BilaterFilterFactor", 1.0f - settings.BilaterFilterStrength);
            material.SetFloat("_BlurRadius", settings.BlurRadius);

            cmd.Blit(source, AO_Tex.Identifier(), material, 0);
            cmd.SetGlobalTexture("_AOTex", AO_Tex.Identifier());
            cmd.Blit(AO_Tex.Identifier(), AO_Tex.Identifier(), material, 1);
            cmd.SetGlobalTexture("_AOTex", AO_Tex.Identifier());
            cmd.Blit(source, dest, material, 2);
            cmd.ReleaseTemporaryRT(AO_Tex.id);
        }
    }
}
