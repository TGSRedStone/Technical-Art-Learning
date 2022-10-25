using UnityEngine;

namespace Scenes.Cloud.UsingGraphicsDrawMesh
{
    public class VolumetricColud : MonoBehaviour
    {
        public int CloudCount = 20;
        public float CloudHeight = 1f;
        public Mesh CloudMesh;
        public Material CloudMaterial;
        public int layer;
        public bool useGpuInstancing = false;

        private float offset;
        private Matrix4x4 matrix;
        private Matrix4x4[] matrices;
        private static readonly int MidY = Shader.PropertyToID("_MidY");
        private static readonly int Height = Shader.PropertyToID("_CloudHeight");

        void Update()
        {
            CloudMaterial.SetFloat(MidY, transform.position.y);
            CloudMaterial.SetFloat(Height, CloudHeight);
            
            offset = CloudHeight / CloudCount / 2f;
            Vector3 startPosition = transform.position + (Vector3.up * (offset * CloudCount / 2f));

            if (useGpuInstancing)
            {
                matrices = new Matrix4x4[CloudCount];
            }

            for (int i = 0; i < CloudCount; i++)
            {
                matrix = Matrix4x4.TRS(startPosition - (Vector3.up * offset * i), transform.rotation, transform.localScale);
                if (useGpuInstancing)
                {
                    matrices[i] = matrix;
                }
                else
                {
                    Graphics.DrawMesh(CloudMesh, matrix, CloudMaterial, layer);
                }
            }

            if (useGpuInstancing)
            {
                Graphics.DrawMeshInstanced(CloudMesh, 0, CloudMaterial, matrices, CloudCount);
            }
        }
    }
}
