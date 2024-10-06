using UnityEngine;

namespace Scenes.Cloud.VolumeCloud.Clouds.NoiseSettings
{
    [CreateAssetMenu(menuName = "Graphics/WeatherMapSettings")]
    public class WeatherMapSettings : ScriptableObject
    {
        public int seed;
        [Range(1, 6)] public int layers = 1;
        public float scale = 1;
        public float lacuna = 2;
        public float persistence = 0.5f;
        public Vector2 offset;

        public System.Array GetDataArray()
        {
            var data = new DataStruct()
            {
                Seed = seed,
                Layers = Mathf.Max(1, layers),
                Scale = scale,
                Lacuna = lacuna,
                Persistence = persistence,
                Offset = offset
            };

            return new[] { data };
        }

        private struct DataStruct
        {
            public int Seed;
            public int Layers;
            public float Scale;
            public float Lacuna;
            public float Persistence;
            public Vector2 Offset;
        }
    }
}