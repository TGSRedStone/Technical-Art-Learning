using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

namespace Scenes.Fog
{
    public class FogRenderFeature : ScriptableRendererFeature
    {
        [System.Serializable]
        public class BlitSettings
        {
            public RenderPassEvent Event = RenderPassEvent.AfterRenderingOpaques;
            public Shader Shader = null;

            public float FogStartDensity = 0;
            public float FogAttenuationIndex = 2;
            public Color FogColor = Color.white;
            public float FogStartDistance = 10;
            public float FogStartHeight = 10;
        }

        public BlitSettings Settings = new BlitSettings();
        private FogRenderPass fogRenderPass;
        
        public override void Create()
        {
            if (Settings.Shader == null)
            {
                Debug.LogError("shader not exist");
                return;
            }

            fogRenderPass = new FogRenderPass(Settings, name);
        }

        public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
        {
            renderer.EnqueuePass(fogRenderPass);
        }

        private class FogRenderPass : ScriptableRenderPass
        {
            private Material material = null;
            private string profilerTag;
            private BlitSettings blitSettings;
            
            private RenderTargetIdentifier source { get; set; }
            private RenderTargetHandle temp { get; set; }
            
            public FogRenderPass(BlitSettings settings, string tag)
            {
                this.renderPassEvent = settings.Event;
                blitSettings = settings;
                this.material = CoreUtils.CreateEngineMaterial(settings.Shader);
                this.profilerTag = tag;
            }

            public override void OnCameraSetup(CommandBuffer cmd, ref RenderingData renderingData)
            {
                Matrix4x4 view = renderingData.cameraData.GetViewMatrix();
                Matrix4x4 proj = GL.GetGPUProjectionMatrix(renderingData.cameraData.GetProjectionMatrix(), renderingData.cameraData.IsCameraProjectionMatrixFlipped());
                Matrix4x4 vp = proj * view;
                material.SetMatrix("_MATRIX_I_VP", vp.inverse);
                
                material.SetFloat("_a", blitSettings.FogStartDensity);
                material.SetFloat("_b", blitSettings.FogAttenuationIndex);
                material.SetVector("_fogColor", blitSettings.FogColor);
                material.SetFloat("_startDis", blitSettings.FogStartDistance);
                material.SetFloat("_startHeight", blitSettings.FogStartHeight);
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
                
                RenderTextureDescriptor opaqueDesc = renderingData.cameraData.cameraTargetDescriptor;
                opaqueDesc.depthBufferBits = 0;
                cmd.GetTemporaryRT(temp.id, opaqueDesc);

                cmd.Blit(source, temp.Identifier(), material);
                cmd.Blit(temp.Identifier(), source);
                
                context.ExecuteCommandBuffer(cmd);
                CommandBufferPool.Release(cmd);
            }

            public override void FrameCleanup(CommandBuffer cmd)
            {
                cmd.ReleaseTemporaryRT(temp.id);
            }
        }
    }
}