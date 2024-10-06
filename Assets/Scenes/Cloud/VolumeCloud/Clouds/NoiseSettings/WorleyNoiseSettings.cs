using UnityEngine;

namespace Scenes.Cloud.VolumeCloud.Clouds.NoiseSettings
{
    [CreateAssetMenu(menuName = "Graphics/NoiseSettings")]
    public class WorleyNoiseSettings : ScriptableObject
    {
        public int seed;
        [Range(1, 32)] public int numCellsA = 8;
        [Range(1, 32)] public int numCellsB = 16;
        [Range(1, 32)] public int numCellsC = 24;
        [Range(1, 256)]public int resolution = 128;
        [Range(-5, 5)]public float persistence = 0.5f;
        [Range(1, 10)]public int tile = 1;
        public bool invert = true;
    }
}