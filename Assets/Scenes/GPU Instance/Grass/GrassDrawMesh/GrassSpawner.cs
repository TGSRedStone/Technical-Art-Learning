using System;
using System.Collections.Generic;
using UnityEngine;

namespace Scenes.GPU_Instance.Grass.GrassDrawMesh
{
    [ExecuteInEditMode]
    public class GrassSpawner : MonoBehaviour
    {
        private static HashSet<GrassSpawner> _spawners = new HashSet<GrassSpawner>();

        public static IReadOnlyCollection<GrassSpawner> Spawners
        {
            get
            {
                return _spawners;
            }
        }

        [SerializeField]
        private Material _material;

        public Material material
        {
            get
            {
                return _material;
            }
        }

        private MaterialPropertyBlock _materialPropertyBlock;

        public MaterialPropertyBlock materialPropertyBlock
        {
            get
            {
                if (_materialPropertyBlock == null)
                {
                    _materialPropertyBlock = new MaterialPropertyBlock();
                }

                return _materialPropertyBlock;
            }
        }

        [SerializeField]
        private int grassCountPerMeter = 100;

        private int seed;

        private int _grassCount;

        public int grassCount
        {
            get
            {
                return _grassCount;
            }
        }
    
        [SerializeField]
        private Vector2 _grassQuadSize = new Vector2(0.1f,0.6f);
    
        public struct GrassData
        {
            public Matrix4x4 grassToSpawner;
            public Vector4 uvOffset;
        }

        private ComputeBuffer _grassBuffer;

        public ComputeBuffer grassBuffer
        {
            get
            {
                if (_grassBuffer != null)
                {
                    return _grassBuffer;
                }

                var filter = GetComponent<MeshFilter>();
                var spawnerMesh = filter.sharedMesh;
                var grassIndex = 0;
                List<GrassData> grassDatas = new List<GrassData>();
                var maxGrassCount = 20000;
                UnityEngine.Random.InitState(seed);

                var indice = spawnerMesh.triangles;
                var vertices = spawnerMesh.vertices;

                for (int i = 0; i < indice.Length / 3 && grassIndex <= maxGrassCount; i++)
                {
                    var index1 = indice[i * 3];
                    var index2 = indice[i * 3 + 1];
                    var index3 = indice[i * 3 + 2];
                    var v1 = vertices[index1];
                    var v2 = vertices[index2];
                    var v3 = vertices[index3];

                    var spawnerFaceNormal = GrassUtility.GetFaceNormal(v1, v2, v3);
                    var upToFaceNormal = Quaternion.FromToRotation(Vector3.up, spawnerFaceNormal);
                    var triangleArea = GrassUtility.CalculateTriangleArea(v1, v2, v3);
                    var grassCountPerTriangle = Mathf.Max(1, grassCountPerMeter * triangleArea);
                
                    for (int j = 0; j < grassCountPerTriangle && grassIndex <= maxGrassCount; j++)
                    {
                        var grassOffset = GrassUtility.RandomPointInTriangle(v1, v2, v3);
                        var rotate = UnityEngine.Random.Range(0, 180);
                        var grassToSpawner = Matrix4x4.TRS(grassOffset, upToFaceNormal * Quaternion.Euler(0, rotate, 0),
                            Vector3.one);
                        Vector4 uvOffset = new Vector4(1, 1, 0, 0);
                        var grassData = new GrassData()
                        {
                            grassToSpawner = grassToSpawner,
                            uvOffset = uvOffset
                        };
                        grassDatas.Add(grassData);
                        grassIndex++;
                    }
                }
                _grassCount = grassIndex;
                _grassBuffer = new ComputeBuffer(_grassCount, 64 + 16);
                _grassBuffer.SetData(grassDatas);
                return _grassBuffer;
            }
        }

        [ContextMenu("UpdateGrassBuffer")]
        private void UpdateGrassBuffer()
        {
            if (_grassBuffer != null)
            {
                _grassBuffer.Dispose();
                _grassBuffer = null;
            }

            UpdateMaterialProperties();
        }

        private void Awake()
        {
            seed = Guid.NewGuid().GetHashCode();
        }

        private void OnEnable()
        {
            _spawners.Add(this);
        }

        private void OnDisable()
        {
            _spawners.Remove(this);
            if (_grassBuffer != null)
            {
                _grassBuffer.Dispose();
                _grassBuffer = null;
            }
        }

        public void UpdateMaterialProperties()
        {
            materialPropertyBlock.SetMatrix(ShaderProperties.LocalToWorld, transform.localToWorldMatrix);
            materialPropertyBlock.SetBuffer(ShaderProperties.GrassDatas, grassBuffer);
            materialPropertyBlock.SetVector(ShaderProperties.GrassQuadSize, _grassQuadSize);
        }
    
        private class ShaderProperties
        {
            public static readonly int LocalToWorld = Shader.PropertyToID("_LocalToWorld");
            public static readonly int GrassDatas = Shader.PropertyToID("_GrassDatas");
            public static readonly int GrassQuadSize = Shader.PropertyToID("_GrassQuadSize");
        }
    }
}
