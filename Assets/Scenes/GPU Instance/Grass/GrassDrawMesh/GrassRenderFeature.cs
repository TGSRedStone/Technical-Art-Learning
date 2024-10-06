using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

namespace Scenes.GPU_Instance.Grass.GrassDrawMesh
{
    public class GrassRenderFeature : ScriptableRendererFeature
    {
        private GrassRenderPass grassRenderPass;

        public override void Create()
        {
            grassRenderPass = new GrassRenderPass();
        }

        public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
        {
            if (renderingData.cameraData.renderType == CameraRenderType.Base)
            {
                renderer.EnqueuePass(grassRenderPass);
            }
        }

        private class GrassRenderPass : ScriptableRenderPass
        {
            private const string profilerTag = "Grass";

            public GrassRenderPass()
            {
                renderPassEvent = RenderPassEvent.BeforeRenderingOpaques;
            }

            public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
            {
                CommandBuffer cmd = CommandBufferPool.Get(profilerTag);
                foreach (var spawner in GrassSpawner.Spawners)
                {
                    if (!spawner)
                    {
                        continue;
                    }

                    if (!spawner.material)
                    {
                        continue;
                    }

                    spawner.UpdateMaterialProperties();
                    cmd.DrawMeshInstancedProcedural(GrassUtility.grassMesh, 0, spawner.material, 0, spawner.grassCount,
                        spawner.materialPropertyBlock);
                }

                context.ExecuteCommandBuffer(cmd);
                CommandBufferPool.Release(cmd);
            }
        }
    }
}