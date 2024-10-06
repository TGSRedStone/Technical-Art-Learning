using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

public class TAAPostProcessing : ScriptableRendererFeature
{
    [System.Serializable]
    public class BlitSettings
    {
        public RenderPassEvent Event = RenderPassEvent.AfterRenderingOpaques;
        public Shader Shader = null;
        public int blitMaterialPassIndex = 0;
        [Range(0f, 5f)] public float jitter = 1f;
        [Range(0f, 1f)] public float blend = 0.05f;
    }

    public BlitSettings Settings = new BlitSettings();
    private TAAPass taaPass;

    public override void Create()
    {
        if (Settings.Shader == null)
        {
            Debug.LogError("shader not exist");
            return;
        }
        var passIndex = Settings.Shader.passCount - 1;
        Settings.blitMaterialPassIndex = Mathf.Clamp(Settings.blitMaterialPassIndex, -1, passIndex);
        taaPass = new TAAPass(Settings, name);
    }

    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        renderingData.cameraData.camera.ResetProjectionMatrix();
        renderer.EnqueuePass(taaPass);
        taaPass.source = renderer.cameraColorTarget;
    }

    class TAAPass : ScriptableRenderPass
    {
        private Material material = null;
        private static readonly int mainTexId = Shader.PropertyToID("_MainTex");

        private BlitSettings settings;
        
        public RenderTargetIdentifier source { get; set; }

        private RenderTexture preRT;

        private string profilerTag;
        
        private Vector2[] HaltonSequence9 = new Vector2[]
        {
            new Vector2(0.5f, 1.0f / 3f),
            new Vector2(0.25f, 2.0f / 3f),
            new Vector2(0.75f, 1.0f / 9f),
            new Vector2(0.125f, 4.0f / 9f),
            new Vector2(0.625f, 7.0f / 9f),
            new Vector2(0.375f, 2.0f / 9f),
            new Vector2(0.875f, 5.0f / 9f),
            new Vector2(0.0625f, 8.0f / 9f),
            new Vector2(0.5625f, 1.0f / 27f),
        };
        
        private int index = 0;
        private Camera camera;
        
        
        public TAAPass(BlitSettings settings, string tag)
        {
            this.renderPassEvent = settings.Event;
            this.settings = settings;
            this.material = CoreUtils.CreateEngineMaterial(settings.Shader);
            this.profilerTag = tag;
        }

        public override void OnCameraSetup(CommandBuffer cmd, ref RenderingData renderingData)
        {
            camera = renderingData.cameraData.camera;
            camera.ResetProjectionMatrix();
            Matrix4x4 pm = camera.projectionMatrix;
            Vector2 jitter = new Vector2((HaltonSequence9[index].x - 0.5f) / camera.pixelWidth,
                (HaltonSequence9[index].y - 0.5f) / camera.pixelHeight);
            jitter *= settings.jitter;
            pm.m02 += jitter.x * 2;
            pm.m12 += jitter.y * 2;
            camera.projectionMatrix = pm;
            index = (index + 1) % 9;
        }

        public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
        {
            if (!renderingData.cameraData.postProcessEnabled || renderingData.cameraData.isSceneViewCamera)
            {
                return;
            }

            material.SetFloat("_Blend", settings.blend);
            
            CommandBuffer cmd = CommandBufferPool.Get(profilerTag);
            
            cmd.SetGlobalTexture(mainTexId, source);

            if (preRT == null || preRT.width != camera.pixelWidth || preRT.height != camera.pixelHeight)
            {
                preRT = RenderTexture.GetTemporary(camera.pixelWidth, camera.pixelHeight, 0, RenderTextureFormat.DefaultHDR);
                cmd.Blit(source, preRT);
                material.SetTexture("_PreTex", preRT);
            }

            int des = Shader.PropertyToID("_Temp");
            cmd.GetTemporaryRT(des, camera.pixelWidth, camera.pixelHeight, 0, FilterMode.Bilinear
                , RenderTextureFormat.DefaultHDR);
            cmd.Blit(source, des);
            cmd.Blit(des, source, material, 0);
            cmd.Blit(source, preRT);
            material.SetTexture("_preTex", preRT);
            
            cmd.ReleaseTemporaryRT(des);
            context.ExecuteCommandBuffer(cmd);
            CommandBufferPool.Release(cmd);
        }
    }
}
