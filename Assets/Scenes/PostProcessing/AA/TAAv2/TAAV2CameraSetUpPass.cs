using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

namespace Scenes.PostProcessing.AA.TAAv2
{
    public class TAAV2CameraSetUpPass : ScriptableRenderPass
    {
        private ProfilingSampler profilingSampler;
        private TAAData taaData;
        private readonly string profilerTag;

        public TAAV2CameraSetUpPass(string tag)
        {
            profilerTag = tag;
            renderPassEvent = RenderPassEvent.BeforeRenderingOpaques;
        }

        internal void SetUp(TAAData data)
        {
            taaData = data;
        }

        public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
        {
            CommandBuffer cmd = CommandBufferPool.Get(profilerTag);
            using (new ProfilingScope(cmd, profilingSampler))
            {
                context.ExecuteCommandBuffer(cmd);
                cmd.Clear();
                cmd.SetViewProjectionMatrices(renderingData.cameraData.camera.worldToCameraMatrix, taaData.Project);
            }
            context.ExecuteCommandBuffer(cmd);
            CommandBufferPool.Release(cmd);
        }
    }
}