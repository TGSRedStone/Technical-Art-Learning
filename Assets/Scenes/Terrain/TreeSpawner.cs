using System.Collections.Generic;
using DefaultNamespace;
using Unity.Mathematics;
using UnityEngine;
using UnityEngine.Profiling;
using Random = UnityEngine.Random;

namespace Scenes.Terrain
{
    public struct TreePoint
    {
        public Vector3 Position;
    }

    public class TreeSpawner : SingletonMono<TreeSpawner>
    {
        public float DrawDistance = 100;
        public Material TreeMaterial;
        public ComputeShader CullingComputerShader;
        [HideInInspector] public List<TreePoint> AllTreePosition = new List<TreePoint>();
        public Mesh TreeMesh;

        private int cellCountX = -1;
        private int cellCountZ = -1;
        private int dispatchCount = -1;
        private float cellSizeX = 25;
        private float cellSizeZ = 25;
        private int grassCountCache = -1;

        private ComputeBuffer allInstanceTransformBuffer;
        private ComputeBuffer onlyInstanceVisibleIDBuffer;
        private ComputeBuffer argsBuffer;

        private List<TreePoint>[] treeCells;
        private float minX, minZ, maxX, maxZ;
        private List<int> visibleCellsID = new List<int>();
        private Plane[] cameraFrustumPlanes = new Plane[6];

        private Camera mainCamera;

        private bool shouldBatchDispatch = true;

        public GameObject[] TreePrefab;

        private void Start()
        {
            mainCamera = Camera.main;
            InstancedPoints instancedPoints = new InstancedPoints();
            instancedPoints.LoadTreePoints();
            for (int i = 0; i < AllTreePosition.Count; i++)
            {
                var obj = Instantiate(TreePrefab[Random.Range(0, TreePrefab.Length)], AllTreePosition[i].Position, Quaternion.Euler(0, Random.Range(0, 360), 0));
                obj.transform.localScale = new Vector3(Random.Range(1f, 2f), Random.Range(1f, 2f), Random.Range(1f, 2f));
            }
        }

        // private void LateUpdate()
        // {
        //     UpdateBuffer();
        //     visibleCellsID.Clear();
        //     float cameraOriginFarPlane = mainCamera.farClipPlane;
        //     mainCamera.farClipPlane = DrawDistance;
        //     GeometryUtility.CalculateFrustumPlanes(mainCamera, cameraFrustumPlanes);
        //     mainCamera.farClipPlane = cameraOriginFarPlane;
        //
        //     Profiler.BeginSample("CPU Cell");
        //
        //     for (int i = 0; i < treeCells.Length; i++)
        //     {
        //         Vector3 centerPosition = new Vector3(i % cellCountX + 0.5f, 300, i / cellCountX + 0.5f);
        //         centerPosition.x = Mathf.Lerp(minX, maxX, centerPosition.x / cellCountX);
        //         centerPosition.z = Mathf.Lerp(minZ, maxZ, centerPosition.z / cellCountZ);
        //
        //         Vector3 size = new Vector3(Mathf.Abs(maxX - minX) / cellCountX, 600, Mathf.Abs(maxX - minX) / cellCountX);
        //         Bounds cellBound = new Bounds(centerPosition, size);
        //
        //         if (GeometryUtility.TestPlanesAABB(cameraFrustumPlanes, cellBound))
        //         {
        //             visibleCellsID.Add(i);
        //         }
        //     }
        //
        //     Profiler.EndSample();
        //
        //     Matrix4x4 v = mainCamera.worldToCameraMatrix;
        //     Matrix4x4 p = mainCamera.projectionMatrix;
        //     Matrix4x4 vp = p * v;
        //
        //     onlyInstanceVisibleIDBuffer.SetCounterValue(0);
        //
        //     CullingComputerShader.SetMatrix("_VPMatrix", vp);
        //     CullingComputerShader.SetFloat("_MaxDrawDistance", DrawDistance);
        //
        //     dispatchCount = 0;
        //     for (int i = 0; i < visibleCellsID.Count; i++)
        //     {
        //         int targetCellFlattenID = visibleCellsID[i];
        //         int memoryOffset = 0;
        //         for (int j = 0; j < targetCellFlattenID; j++)
        //         {
        //             memoryOffset += treeCells[j].Count;
        //         }
        //
        //         CullingComputerShader.SetInt("_StartOffset", memoryOffset);
        //         int jobLength = treeCells[targetCellFlattenID].Count;
        //
        //         if (shouldBatchDispatch)
        //         {
        //             while (i < visibleCellsID.Count - 1 && (visibleCellsID[i + 1] == visibleCellsID[i] + 1))
        //             {
        //                 jobLength += treeCells[visibleCellsID[i + 1]].Count;
        //                 i++;
        //             }
        //         }
        //
        //         if (jobLength <= 0)
        //         {
        //             continue;
        //         }
        //
        //         CullingComputerShader.Dispatch(0, Mathf.CeilToInt(jobLength / 64f), 1, 1);
        //         dispatchCount++;
        //     }
        //
        //     ComputeBuffer.CopyCount(onlyInstanceVisibleIDBuffer, argsBuffer, 4);
        //
        //     Bounds renderBound = new Bounds();
        //     renderBound.SetMinMax(new Vector3(minX, 0, minZ), new Vector3(maxX, 0, maxZ));
        //     Graphics.DrawMeshInstancedIndirect(TreeMesh, 0, TreeMaterial, renderBound, argsBuffer);
        // }
        //
        // private void OnDisable()
        // {
        //     if (allInstanceTransformBuffer != null)
        //     {
        //         allInstanceTransformBuffer.Release();
        //     }
        //
        //     allInstanceTransformBuffer = null;
        //
        //     if (onlyInstanceVisibleIDBuffer != null)
        //     {
        //         onlyInstanceVisibleIDBuffer.Release();
        //     }
        //
        //     onlyInstanceVisibleIDBuffer = null;
        //     if (argsBuffer != null)
        //     {
        //         argsBuffer.Release();
        //     }
        //
        //     argsBuffer = null;
        // }
        //
        // private void UpdateBuffer()
        // {
        //     if (grassCountCache == AllTreePosition.Count && argsBuffer != null && allInstanceTransformBuffer != null &&
        //         onlyInstanceVisibleIDBuffer != null)
        //     {
        //         return;
        //     }
        //
        //     if (allInstanceTransformBuffer != null)
        //     {
        //         allInstanceTransformBuffer.Release();
        //     }
        //
        //     allInstanceTransformBuffer = new ComputeBuffer(AllTreePosition.Count, sizeof(float) * 16);
        //
        //     if (onlyInstanceVisibleIDBuffer != null)
        //     {
        //         onlyInstanceVisibleIDBuffer.Release();
        //     }
        //
        //     onlyInstanceVisibleIDBuffer = new ComputeBuffer(AllTreePosition.Count, sizeof(uint), ComputeBufferType.Append);
        //
        //     minX = float.MaxValue;
        //     minZ = float.MaxValue;
        //     maxX = float.MinValue;
        //     maxZ = float.MinValue;
        //     for (int i = 0; i < AllTreePosition.Count; i++)
        //     {
        //         Vector3 target = AllTreePosition[i].Position;
        //         minX = Mathf.Min(target.x, minX);
        //         minZ = Mathf.Min(target.z, minZ);
        //         maxX = Mathf.Max(target.x, maxX);
        //         maxZ = Mathf.Max(target.z, maxZ);
        //     }
        //
        //     cellCountX = Mathf.CeilToInt((maxX - minX) / cellSizeX);
        //     cellCountZ = Mathf.CeilToInt((maxZ - minZ) / cellSizeZ);
        //
        //     treeCells = new List<TreePoint>[cellCountX * cellCountZ];
        //
        //     for (int i = 0; i < treeCells.Length; i++)
        //     {
        //         treeCells[i] = new List<TreePoint>();
        //     }
        //
        //     for (int i = 0; i < AllTreePosition.Count; i++)
        //     {
        //         Vector3 pos = AllTreePosition[i].Position;
        //         int xID = Mathf.Min(cellCountX - 1, Mathf.FloorToInt(Mathf.InverseLerp(minX, maxX, pos.x) * cellCountX));
        //         int zID = Mathf.Min(cellCountZ - 1, Mathf.FloorToInt(Mathf.InverseLerp(minZ, maxZ, pos.z) * cellCountZ));
        //         treeCells[xID + zID * cellCountX].Add(AllTreePosition[i]);
        //     }
        //
        //     int offset = 0;
        //     Matrix4x4[] grassPositionSortedByCell = new Matrix4x4[AllTreePosition.Count];
        //     for (int i = 0; i < treeCells.Length; i++)
        //     {
        //         for (int j = 0; j < treeCells[i].Count; j++)
        //         {
        //             grassPositionSortedByCell[offset] = Matrix4x4.TRS(treeCells[i][j].Position, quaternion.identity, new Vector3(5f, 5f, 5f));
        //             offset++;
        //         }
        //     }
        //
        //     allInstanceTransformBuffer.SetData(grassPositionSortedByCell);
        //     TreeMaterial.SetBuffer("_AllInstancesTransformBuffer", allInstanceTransformBuffer);
        //     TreeMaterial.SetBuffer("_OnlyInstanceVisibleIDBuffer", onlyInstanceVisibleIDBuffer);
        //
        //     if (argsBuffer != null)
        //     {
        //         argsBuffer.Release();
        //     }
        //
        //     uint[] args = new uint[5] { 0, 0, 0, 0, 0 };
        //     argsBuffer = new ComputeBuffer(1, args.Length * sizeof(uint), ComputeBufferType.IndirectArguments);
        //     args[0] = (uint)TreeMesh.GetIndexCount(0);
        //     args[1] = (uint)AllTreePosition.Count;
        //     args[2] = (uint)TreeMesh.GetIndexStart(0);
        //     args[3] = (uint)TreeMesh.GetBaseVertex(0);
        //     args[4] = 0;
        //
        //     argsBuffer.SetData(args);
        //
        //     grassCountCache = AllTreePosition.Count;
        //
        //     CullingComputerShader.SetBuffer(0, "_AllInstancesTransformBuffer", allInstanceTransformBuffer);
        //     CullingComputerShader.SetBuffer(0, "_OnlyInstanceVisibleIDBuffer", onlyInstanceVisibleIDBuffer);
        // }
    }
}