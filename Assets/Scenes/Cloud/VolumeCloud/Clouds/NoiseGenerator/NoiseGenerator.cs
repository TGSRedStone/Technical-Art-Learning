using Scenes.Cloud.VolumeCloud.Clouds.NoiseSettings;
using Unity.Mathematics;
using UnityEngine;
using UnityEngine.Experimental.Rendering;
using UnityEngine.Rendering;
using UnityEngine.SceneManagement;

namespace Scenes.Cloud.VolumeCloud.Clouds.NoiseGenerator
{
    public class NoiseGenerator : MonoBehaviour
    {
        private const int ComputeThreadGroupSize = 8;
        private const string BaseNoiseName = "BaseNoise";
        private const string DetailNoiseName = "DetailNoise";
        public string CurrentRenderTextureName => currentNoiseType == NoiseType.Base ? BaseNoiseName : DetailNoiseName;

        public enum NoiseType
        {
            Base,
            Detail
        }

        public enum TextureChannel
        {
            R,
            G,
            B,
            A
        }

        public NoiseType currentNoiseType;
        public TextureChannel activeChannel;

        [SerializeField] private Material debugMaterial;
        [SerializeField] private MeshRenderer meshRenderer;
        [Range(0.0f, 1.0f)] public float sliceDepth;

        public ComputeShader noiseCompute;
        public ComputeShader slicer;

        public WorleyNoiseSettings[] baseSettings;
        public WorleyNoiseSettings[] detailSettings;
    
        [Header ("Noise Settings")]
        public int baseNoiseResolution = 128;
        public int detailNoiseResolution = 64;
    
        [Header ("Viewer Settings")]
        public bool viewerEnabled;
        public bool viewerGreyscale = true;
        public bool viewerShowAllChannels;
        [Range (0, 1)]
        public float viewerSliceDepth;
        [Range (1, 5)]
        public float viewerTileAmount = 1;
        [Range (0, 1)]
        public float viewerSize = 1;

        public WorleyNoiseSettings CurrentNoiseSettings
        {
            get
            {
                WorleyNoiseSettings[] settings = currentNoiseType == NoiseType.Base ? baseSettings : detailSettings;
                int currentChannelIndex = (int)activeChannel;
                if (currentChannelIndex >= settings.Length)
                {
                    return null;
                }

                return settings[currentChannelIndex];
            }
        }

        private RenderTexture _baseNoiseRenderTexture;
        private RenderTexture _detailNoiseRenderTexture;

        public RenderTexture CurrentRenderTexture =>
            currentNoiseType == NoiseType.Base ? _baseNoiseRenderTexture : _detailNoiseRenderTexture;

        public void Generate()
        {
            GenerateWorley3D();
        }

        private void GenerateWorley3D()
        {
            meshRenderer.sharedMaterial = debugMaterial;
            Create3DRenderTexture(ref _baseNoiseRenderTexture, baseNoiseResolution, BaseNoiseName);
            Create3DRenderTexture(ref _detailNoiseRenderTexture, detailNoiseResolution, DetailNoiseName);

            noiseCompute.SetFloat("persistence", CurrentNoiseSettings.persistence);
            noiseCompute.SetInt("resolution", CurrentRenderTexture.width);
            noiseCompute.SetVector ("channelMask", ChannelMask);
            noiseCompute.SetInt("numCellsA", CurrentNoiseSettings.numCellsA);
            noiseCompute.SetInt("numCellsB", CurrentNoiseSettings.numCellsB);
            noiseCompute.SetInt("numCellsC", CurrentNoiseSettings.numCellsC);
            noiseCompute.SetInt("tile", CurrentNoiseSettings.tile);
            noiseCompute.SetBool("invertNoise", CurrentNoiseSettings.invert);
            noiseCompute.SetTexture(0, "Result", CurrentRenderTexture);
            var random = new System.Random(CurrentNoiseSettings.seed);
            var bufferA = Create3DWorleyPointsBuffer(random, CurrentNoiseSettings.numCellsA);
            var bufferB = Create3DWorleyPointsBuffer(random, CurrentNoiseSettings.numCellsB);
            var bufferC = Create3DWorleyPointsBuffer(random, CurrentNoiseSettings.numCellsC);
            noiseCompute.SetBuffer(0, "pointsA", bufferA);
            noiseCompute.SetBuffer(0, "pointsB", bufferB);
            noiseCompute.SetBuffer(0, "pointsC", bufferC);

            int threadsPerGroup = Mathf.CeilToInt(CurrentNoiseSettings.resolution / (float)ComputeThreadGroupSize);
            noiseCompute.Dispatch(0, threadsPerGroup, threadsPerGroup, threadsPerGroup);

            bufferA.Release();
            bufferB.Release();
            bufferC.Release();

            meshRenderer.sharedMaterial.SetTexture("_BaseMap", CurrentRenderTexture);
        }

        private void Create3DRenderTexture(ref RenderTexture renderTexture, int resolution, string rtName)
        {
            var format = GraphicsFormat.R16G16B16A16_UNorm;
            if (renderTexture == null || !renderTexture.IsCreated() || renderTexture.width != resolution ||
                renderTexture.height != resolution || renderTexture.volumeDepth != resolution ||
                renderTexture.graphicsFormat != format)
            {
                if (renderTexture != null)
                {
                    renderTexture.Release();
                }

                renderTexture = new RenderTexture(resolution, resolution, 0)
                {
                    enableRandomWrite = true,
                    volumeDepth = resolution,
                    name = rtName,
                    graphicsFormat = format,
                    dimension = TextureDimension.Tex3D,
                    wrapMode = TextureWrapMode.Repeat,
                    filterMode = FilterMode.Bilinear
                };
                renderTexture.Create();
            }
        }

        private ComputeBuffer Create3DWorleyPointsBuffer(System.Random random, int numCells)
        {
            var pointCount = numCells * numCells * numCells;
            var points = new float3[pointCount];

            for (int i = 0; i < pointCount; i++)
            {
                points[i] = new float3((float)random.NextDouble(), (float)random.NextDouble(), (float)random.NextDouble());
            }

            var computeBuffer = new ComputeBuffer(points.Length, sizeof(float) * 3, ComputeBufferType.Structured);
            computeBuffer.SetData(points);
            return computeBuffer;
        }

        public void Save(RenderTexture volumeTexture, string saveName)
        {
#if UNITY_EDITOR
            string sceneName = SceneManager.GetActiveScene().name;
            saveName = sceneName + "_" + saveName;
            int resolution = volumeTexture.width;
            Texture2D[] slices = new Texture2D[resolution];

            slicer.SetInt("resolution", resolution);
            slicer.SetTexture(0, "volumeTexture", volumeTexture);

            for (int layer = 0; layer < resolution; layer++)
            {
                var slice = new RenderTexture(resolution, resolution, 0);
                slice.dimension = UnityEngine.Rendering.TextureDimension.Tex2D;
                slice.enableRandomWrite = true;
                slice.Create();

                slicer.SetTexture(0, "slice", slice);
                slicer.SetInt("layer", layer);
                int numThreadGroups = Mathf.CeilToInt(resolution / (float)32);
                slicer.Dispatch(0, numThreadGroups, numThreadGroups, 1);

                slices[layer] = ConvertFromRenderTexture(slice);
            }

            var x = Tex3DFromTex2DArray(slices, resolution);
            UnityEditor.AssetDatabase.CreateAsset(x, "Assets/Scripts/Graphics/Clouds/" + saveName + ".asset");
#endif
        }

        Texture3D Tex3DFromTex2DArray(Texture2D[] slices, int resolution)
        {
            Texture3D tex3D = new Texture3D(resolution, resolution, resolution, TextureFormat.ARGB32, false);
            tex3D.filterMode = FilterMode.Trilinear;
            Color[] outputPixels = tex3D.GetPixels();

            for (int z = 0; z < resolution; z++)
            {
                Color[] layerPixels = slices[z].GetPixels();
                for (int x = 0; x < resolution; x++)
                for (int y = 0; y < resolution; y++)
                {
                    outputPixels[x + resolution * (y + z * resolution)] = layerPixels[x + y * resolution];
                }
            }

            tex3D.SetPixels(outputPixels);
            tex3D.Apply();

            return tex3D;
        }

        Texture2D ConvertFromRenderTexture(RenderTexture rt)
        {
            Texture2D output = new Texture2D(rt.width, rt.height);
            RenderTexture.active = rt;
            output.ReadPixels(new Rect(0, 0, rt.width, rt.height), 0, 0);
            output.Apply();
            return output;
        }
    
        public Vector4 ChannelMask {
            get
            {
                Vector4 channelWeight = new Vector4(
                    (activeChannel == TextureChannel.R) ? 1 : 0,
                    (activeChannel == TextureChannel.G) ? 1 : 0,
                    (activeChannel == TextureChannel.B) ? 1 : 0,
                    (activeChannel == TextureChannel.A) ? 1 : 0
                );
                return channelWeight;
            }
        }

        private void OnValidate()
        {
            debugMaterial.SetFloat("_SliceDepth", sliceDepth);
        }
    }
}