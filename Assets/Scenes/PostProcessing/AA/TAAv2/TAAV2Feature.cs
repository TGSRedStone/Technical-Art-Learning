using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

namespace Scenes.PostProcessing.AA.TAAv2
{
    public class TAAV2Feature : ScriptableRendererFeature
    {
        private Matrix4x4 prevProject;
        private Matrix4x4 prevView;
        private TAAV2Pass taaV2Pass;
        private TAAV2CameraSetUpPass cameraSetUpPass;

        public override void Create()
        {
            cameraSetUpPass = new TAAV2CameraSetUpPass("TAACameraSetUp");
            taaV2Pass = new TAAV2Pass();
        }

        public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
        {
            var camera = renderingData.cameraData.camera;
            var taaData = new TAAData();

            var stack = VolumeManager.instance.stack;
            var taaComponent = stack.GetComponent<TAAV2>();
            if (taaComponent.IsActive() && !renderingData.cameraData.isSceneViewCamera)
            {
                UpdateTaaData(renderingData, taaData, taaComponent);
                cameraSetUpPass.SetUp(taaData);
                renderer.EnqueuePass(cameraSetUpPass);
                taaV2Pass.SetUp(taaData, taaComponent);
                renderer.EnqueuePass(taaV2Pass);
            }
            else if (!taaComponent.IsActive())
            {
                taaV2Pass.Clear();
            }
        }

        private void UpdateTaaData(RenderingData renderingData, TAAData taaData, TAAV2 taa)
        {
            var camera = renderingData.cameraData.camera;
            Vector2 offset = Utils.GenerateRandomOffset() * taa.Spread.value;
            taaData.SampleOffset = offset;
            taaData.PrevProject = prevProject;
            taaData.PrevView = prevView;
            taaData.Project = Utils.GetJitteredProjectionMatrix(camera, taaData.SampleOffset);
            taaData.SampleOffset = new Vector2(taaData.SampleOffset.x / camera.scaledPixelWidth, taaData.SampleOffset.y / camera.scaledPixelHeight);
            prevProject = camera.projectionMatrix;
            prevView = camera.worldToCameraMatrix;
        }
    }
}