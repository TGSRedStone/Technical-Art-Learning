using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

namespace Scenes.PostProcessing.AA.TAAv2
{
    internal static class ShaderKeywordStrings
    {
        internal static readonly string HighTAAQuality = "_HIGH_TAA";
        internal static readonly string MiddleTAAQuality = "_MIDDLE_TAA";
        internal static readonly string LOWTAAQuality = "_LOW_TAA";
    }
    
    internal class ShaderConstants
    {
        public static readonly int TAAParams = Shader.PropertyToID("_TAAParams");
        public static readonly int TAAPrevRT = Shader.PropertyToID("_TAAPrevRT");
        public static readonly int TAAPrevVP = Shader.PropertyToID("_TAAPrevVP");
        public static readonly int TAACurInvView = Shader.PropertyToID("_TAACurInvView");
        public static readonly int TAACurInvProject = Shader.PropertyToID("_TAACurInvProject");
    }

    public class TAAV2Pass : ScriptableRenderPass
    {
        private const string TAA_SHADER = "PostProcessing/AA/TAAV2";
        private RenderTexture[] historyBuffer;
        private int indexWrite = 0;
        private TAAData taaData;
        private TAAV2 taaV2;
        private Material material;
        private ProfilingSampler profilingSampler;
        private readonly string profilerTag = "TAAPass";

        public TAAV2Pass()
        {
            renderPassEvent = RenderPassEvent.BeforeRenderingPostProcessing;
        }

        internal void SetUp(TAAData taaData, TAAV2 taaV2)
        {
            this.taaData = taaData;
            this.taaV2 = taaV2;
            material = new Material(Shader.Find(TAA_SHADER));
        }

        private void ReleaseRT(ref RenderTexture rt)
        {
            if (rt != null)
            {
                RenderTexture.ReleaseTemporary(rt);
                rt = null;
            }
        }

        internal void Clear()
        {
            if (historyBuffer != null)
            {
                ReleaseRT(ref historyBuffer[0]);
                ReleaseRT(ref historyBuffer[1]);
                historyBuffer = null;
            }
        }

        private void EnsureArray<T>(ref T[] array, int size, T initialValue = default(T))
        {
            if (array == null || array.Length != size)
            {
                array = new T[size];
                for (int i = 0; i < size; i++)
                {
                    array[i] = initialValue;
                }
            }
        }

        private void EnsureRenderTarget(ref RenderTexture rt, int width, int height, RenderTextureFormat format, FilterMode filterMode,
            int depthBits = 0, int antiAliasing = 1)
        {
            if (rt != null && (rt.height != height || rt.format != format || rt.filterMode != filterMode || rt.antiAliasing != antiAliasing))
            {
                RenderTexture.ReleaseTemporary(rt);
                rt = null;
            }

            if (rt == null)
            {
                rt = RenderTexture.GetTemporary(width, height, depthBits, format, RenderTextureReadWrite.Default, antiAliasing);
                rt.filterMode = filterMode;
                rt.wrapMode = TextureWrapMode.Clamp;
            }
        }

        private void DoTemporalAntiAliasing(CameraData cameraData, CommandBuffer cmd)
        {
            var camera = cameraData.camera;
            if (camera.cameraType == CameraType.Preview)
            {
                return;
            }

            var colorTextureIdentifier = new RenderTargetIdentifier("_CameraColorTexture");
            var descriptor = new RenderTextureDescriptor(camera.scaledPixelWidth, camera.scaledPixelHeight, RenderTextureFormat.Default, 16);
            EnsureArray(ref historyBuffer, 2);
            EnsureRenderTarget(ref historyBuffer[0], descriptor.width, descriptor.height, descriptor.colorFormat, FilterMode.Bilinear);
            EnsureRenderTarget(ref historyBuffer[1], descriptor.width, descriptor.height, descriptor.colorFormat, FilterMode.Bilinear);

            int indexRead = indexWrite;
            indexWrite = (++indexWrite) % 2;

            Matrix4x4 invProjectJittered = Matrix4x4.Inverse(taaData.Project);
            Matrix4x4 invViewJittered = Matrix4x4.Inverse(camera.worldToCameraMatrix);
            Matrix4x4 prevVP = taaData.PrevProject * taaData.PrevView;
            material.SetMatrix(ShaderConstants.TAACurInvView, invViewJittered);
            material.SetMatrix(ShaderConstants.TAACurInvProject, invProjectJittered);
            material.SetMatrix(ShaderConstants.TAAPrevVP, prevVP);
            material.SetVector(ShaderConstants.TAAParams, new Vector3(taaData.SampleOffset.x, taaData.SampleOffset.y, taaV2.Feedback.value));
            material.SetTexture(ShaderConstants.TAAPrevRT, historyBuffer[indexRead]);
            CoreUtils.SetKeyword(cmd, ShaderKeywordStrings.HighTAAQuality, taaV2.Quality.value == MotionBlurQuality.High);
            CoreUtils.SetKeyword(cmd, ShaderKeywordStrings.MiddleTAAQuality, taaV2.Quality.value == MotionBlurQuality.Medium);
            CoreUtils.SetKeyword(cmd, ShaderKeywordStrings.LOWTAAQuality, taaV2.Quality.value == MotionBlurQuality.Low);
            cmd.Blit(colorTextureIdentifier, historyBuffer[indexWrite], material);
            cmd.Blit(historyBuffer[indexWrite], colorTextureIdentifier);
        }

        public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
        {
            CommandBuffer cmd = CommandBufferPool.Get(profilerTag);
            using (new ProfilingScope(cmd, profilingSampler))
            {
                context.ExecuteCommandBuffer(cmd);
                cmd.Clear();
                DoTemporalAntiAliasing(renderingData.cameraData, cmd);
            }
            context.ExecuteCommandBuffer(cmd);
            CommandBufferPool.Release(cmd);
        }
    }
}