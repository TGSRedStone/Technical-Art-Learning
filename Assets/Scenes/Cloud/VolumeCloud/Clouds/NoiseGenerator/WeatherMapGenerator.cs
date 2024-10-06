using Scenes.Cloud.VolumeCloud.Clouds.NoiseSettings;
using UnityEngine;
using UnityEngine.Experimental.Rendering;
using UnityEngine.Rendering;
using UnityEngine.SceneManagement;

namespace Scenes.Cloud.VolumeCloud.Clouds.NoiseGenerator
{
    public class WeatherMapGenerator : MonoBehaviour
    {
        public ComputeShader weatherComputer;
        public WeatherMapSettings weatherMapSettings;
        public int resolution = 512;
        public RenderTexture weatherMap;
        public Vector2 minMax = new Vector2 (0, 1);

        public bool viewerEnabled;

        public void GenerateWeatherMap()
        {
            CreateRenderTexture(ref weatherMap, "WeatherMap");
            if (weatherComputer == null)
            {
                return;
            }

            var random = new System.Random(weatherMapSettings.seed);
            var offsets = new Vector2[weatherMapSettings.layers];
            for (int i = 0; i < offsets.Length; i++)
            {
                var offset = new Vector2((float)random.NextDouble(), (float)random.NextDouble());
                offsets[i] = (offset * 2 - Vector2.one) * 1000;
            }

            var pointsBuffer = new ComputeBuffer (offsets.Length, sizeof(float) * 2, ComputeBufferType.Raw);
            pointsBuffer.SetData (offsets);
            weatherComputer.SetBuffer(0, "offsets", pointsBuffer);

            var settingsBuffer = new ComputeBuffer(1, sizeof(float) * 7, ComputeBufferType.Raw);
            settingsBuffer.SetData(weatherMapSettings.GetDataArray());
            weatherComputer.SetBuffer(0, "weatherMapSettings", settingsBuffer);
        
            weatherComputer.SetTexture(0, "Result", weatherMap);
            weatherComputer.SetInt("resolution", resolution);
            weatherComputer.SetVector("minMax", minMax);

            int threadGroupSize = 16;
            int threadsPerGroup = Mathf.CeilToInt(resolution / (float)threadGroupSize);
            weatherComputer.Dispatch(0, threadsPerGroup, threadsPerGroup, 1);
        
            pointsBuffer.Release();
            settingsBuffer.Release();
        }
    
        private void CreateRenderTexture(ref RenderTexture renderTexture, string rtName)
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
                    dimension = TextureDimension.Tex2D,
                    wrapMode = TextureWrapMode.Repeat,
                    filterMode = FilterMode.Bilinear
                };
                renderTexture.Create();
            }
        }
    
        public void Save(RenderTexture texture, string saveName)
        {
#if UNITY_EDITOR
            string sceneName = SceneManager.GetActiveScene().name;
            saveName = sceneName + "_" + saveName;
            var weatherMap = ConvertFromRenderTexture(texture);
        
            UnityEditor.AssetDatabase.CreateAsset(weatherMap, "Assets/Scripts/Graphics/Clouds/" + saveName + ".asset");
#endif
        }

        private Texture2D ConvertFromRenderTexture(RenderTexture rt)
        {
            var output = new Texture2D(rt.width, rt.height, TextureFormat.R16, false);
            RenderTexture.active = rt;
            output.ReadPixels(new Rect(0, 0, rt.width, rt.height), 0, 0);
            output.Apply();
            return output;
        }
    }
}
