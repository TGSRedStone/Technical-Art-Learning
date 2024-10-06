using UnityEngine;

namespace Scenes.PostProcessing.AA.TAAv2
{
    public static class Utils
    {
        private const int SAMPLE_COUNT = 8;
        private static int sampleIndex { get; set; }

        private static float GetHalton(int index, int prime)
        {
            float result = 0.0f;
            float fraction = 1.0f / prime;
            while (index > 0)
            {
                fraction /= prime;
                result += (index % prime) * fraction;
                index /= prime;
            }

            return result;
        }

        public static Vector2 GenerateRandomOffset()
        {
            var offset = new Vector2(
                GetHalton((sampleIndex & 1023) + 1, 2) - 0.5f,
                GetHalton((sampleIndex & 1023) + 1, 3) - 0.5f
            );

            if (++sampleIndex >= SAMPLE_COUNT)
            {
                sampleIndex = 0;
            }

            return offset;
        }

        public static Matrix4x4 GetJitteredProjectionMatrix(Camera camera, Vector2 offset)
        {
            float near = camera.nearClipPlane;
            float far = camera.farClipPlane;
            float vertical = Mathf.Tan(0.5f * Mathf.Deg2Rad * camera.fieldOfView) * near;
            float horizontal = vertical * camera.aspect;
            offset.x *= horizontal / (0.5f * camera.pixelWidth);
            offset.y *= vertical / (0.5f * camera.pixelHeight);
            var matrix = camera.projectionMatrix;
            matrix.m02 += offset.x / horizontal;
            matrix.m12 += offset.y / vertical;
            return matrix;
        }
    }
}