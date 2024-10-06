using System;
using System.Collections.Generic;
using DefaultNamespace;
using HoudiniEngineUnity;
using UnityEngine;
using UnityEngine.Profiling;

namespace Scenes.Terrain
{
    public struct GrassPoint
    {
        public Vector3 Position;
        public Vector3 Normal;
    }

    public class GrassSpawner : SingletonMono<GrassSpawner>
    {
        public float DrawDistance = 100;
        public Material GrassMaterial;
        public ComputeShader CullingComputerShader;
        [HideInInspector] public List<GrassPoint> AllGrassPosition = new List<GrassPoint>();
        public Mesh GrassMesh;

        private int cellCountX = -1;
        private int cellCountZ = -1;
        private int dispatchCount = -1;
        private float cellSizeX = 25;
        private float cellSizeZ = 25;
        private int grassCountCache = -1;

        private ComputeBuffer allInstanceTransformBuffer;
        private ComputeBuffer onlyInstanceVisibleIDBuffer;
        private ComputeBuffer argsBuffer;

        private List<GrassPoint>[] grassCells;
        private float minX, minZ, maxX, maxZ;
        private List<int> visibleCellsID = new List<int>();
        private Plane[] cameraFrustumPlanes = new Plane[6];

        private Camera mainCamera;

        private bool shouldBatchDispatch = true;

        private List<Vector3> cellPositions = new List<Vector3>();
        private List<Vector3> cellSizes = new List<Vector3>();
        private LayerMask terrainLayer;

        private void Start()
        {
            mainCamera = Camera.main;
            InstancedPoints instancedPoints = new InstancedPoints();
            instancedPoints.LoadGrassPoints();
            terrainLayer = LayerMask.GetMask("TerrainLayer");
        }

        private void OnDrawGizmos()
        {
            for (int i = 0; i < cellPositions.Count; i++)
            {
                Gizmos.DrawWireCube(cellPositions[i], cellSizes[i]);
            }
        }

        private void LateUpdate()
        {
            UpdateBuffer();
            visibleCellsID.Clear();
            float cameraOriginFarPlane = mainCamera.farClipPlane;
            mainCamera.farClipPlane = DrawDistance;
            GeometryUtility.CalculateFrustumPlanes(mainCamera, cameraFrustumPlanes);
            mainCamera.farClipPlane = cameraOriginFarPlane;

            cellPositions.Clear();
            cellSizes.Clear();

            Profiler.BeginSample("CPU Cell");

            for (int i = 0; i < grassCells.Length; i++)
            {
                Vector3 centerPosition = new Vector3(i % cellCountX + 0.5f, 0, i / cellCountX + 0.5f);
                centerPosition.x = Mathf.Lerp(minX, maxX, centerPosition.x / cellCountX);
                centerPosition.z = Mathf.Lerp(minZ, maxZ, centerPosition.z / cellCountZ);

                Ray ray = new Ray(new Vector3(centerPosition.x, 600, centerPosition.z), Vector3.down);

                if (Physics.Raycast(ray, out var hitInfo, 2000, terrainLayer))
                {
                    centerPosition.y = hitInfo.point.y;
                }

                Vector3 size = new Vector3(Mathf.Abs(maxX - minX) / cellCountX, 25, Mathf.Abs(maxX - minX) / cellCountX);
                Bounds cellBound = new Bounds(centerPosition, size);

                if (GeometryUtility.TestPlanesAABB(cameraFrustumPlanes, cellBound))
                {
                    visibleCellsID.Add(i);
                    cellPositions.Add(centerPosition);
                    cellSizes.Add(size);
                    // Debug.DrawLine(new Vector3(centerPosition.x, 600, centerPosition.z), centerPosition);
                }
            }

            Profiler.EndSample();

            Matrix4x4 v = mainCamera.worldToCameraMatrix;
            Matrix4x4 p = mainCamera.projectionMatrix;
            Matrix4x4 vp = p * v;

            onlyInstanceVisibleIDBuffer.SetCounterValue(0);

            CullingComputerShader.SetMatrix("_VPMatrix", vp);
            CullingComputerShader.SetFloat("_MaxDrawDistance", DrawDistance);

            dispatchCount = 0;
            for (int i = 0; i < visibleCellsID.Count; i++)
            {
                int targetCellFlattenID = visibleCellsID[i];
                int memoryOffset = 0;
                for (int j = 0; j < targetCellFlattenID; j++)
                {
                    memoryOffset += grassCells[j].Count;
                }

                CullingComputerShader.SetInt("_StartOffset", memoryOffset);
                int jobLength = grassCells[targetCellFlattenID].Count;

                if (shouldBatchDispatch)
                {
                    while (i < visibleCellsID.Count - 1 && (visibleCellsID[i + 1] == visibleCellsID[i] + 1))
                    {
                        jobLength += grassCells[visibleCellsID[i + 1]].Count;
                        i++;
                    }
                }

                if (jobLength <= 0)
                {
                    continue;
                }

                CullingComputerShader.Dispatch(0, Mathf.CeilToInt(jobLength / 64f), 1, 1);
                dispatchCount++;
            }

            ComputeBuffer.CopyCount(onlyInstanceVisibleIDBuffer, argsBuffer, 4);

            Bounds renderBound = new Bounds();
            renderBound.SetMinMax(new Vector3(minX, 0, minZ), new Vector3(maxX, 0, maxZ));
            Graphics.DrawMeshInstancedIndirect(GrassMesh, 0, GrassMaterial, renderBound, argsBuffer);
        }

        private void OnDrawGizmosSelected()
        {
            Gizmos.color = Color.cyan;
            Gizmos.DrawWireCube(transform.position, transform.localScale);
        }

        private void OnDisable()
        {
            if (allInstanceTransformBuffer != null)
            {
                allInstanceTransformBuffer.Release();
            }

            allInstanceTransformBuffer = null;

            if (onlyInstanceVisibleIDBuffer != null)
            {
                onlyInstanceVisibleIDBuffer.Release();
            }

            onlyInstanceVisibleIDBuffer = null;
            if (argsBuffer != null)
            {
                argsBuffer.Release();
            }

            argsBuffer = null;
        }

        private void UpdateBuffer()
        {
            if (grassCountCache == AllGrassPosition.Count && argsBuffer != null && allInstanceTransformBuffer != null &&
                onlyInstanceVisibleIDBuffer != null)
            {
                return;
            }

            if (allInstanceTransformBuffer != null)
            {
                allInstanceTransformBuffer.Release();
            }

            allInstanceTransformBuffer = new ComputeBuffer(AllGrassPosition.Count, sizeof(float) * 16);

            if (onlyInstanceVisibleIDBuffer != null)
            {
                onlyInstanceVisibleIDBuffer.Release();
            }

            onlyInstanceVisibleIDBuffer = new ComputeBuffer(AllGrassPosition.Count, sizeof(uint), ComputeBufferType.Append);

            minX = float.MaxValue;
            minZ = float.MaxValue;
            maxX = float.MinValue;
            maxZ = float.MinValue;
            for (int i = 0; i < AllGrassPosition.Count; i++)
            {
                Vector3 target = AllGrassPosition[i].Position;
                minX = Mathf.Min(target.x, minX);
                minZ = Mathf.Min(target.z, minZ);
                maxX = Mathf.Max(target.x, maxX);
                maxZ = Mathf.Max(target.z, maxZ);
            }

            cellCountX = Mathf.CeilToInt((maxX - minX) / cellSizeX);
            cellCountZ = Mathf.CeilToInt((maxZ - minZ) / cellSizeZ);

            grassCells = new List<GrassPoint>[cellCountX * cellCountZ];

            for (int i = 0; i < grassCells.Length; i++)
            {
                grassCells[i] = new List<GrassPoint>();
            }

            for (int i = 0; i < AllGrassPosition.Count; i++)
            {
                Vector3 pos = AllGrassPosition[i].Position;
                int xID = Mathf.Min(cellCountX - 1, Mathf.FloorToInt(Mathf.InverseLerp(minX, maxX, pos.x) * cellCountX));
                int zID = Mathf.Min(cellCountZ - 1, Mathf.FloorToInt(Mathf.InverseLerp(minZ, maxZ, pos.z) * cellCountZ));
                grassCells[xID + zID * cellCountX].Add(AllGrassPosition[i]);
            }

            int offset = 0;
            Matrix4x4[] grassPositionSortedByCell = new Matrix4x4[AllGrassPosition.Count];
            for (int i = 0; i < grassCells.Length; i++)
            {
                for (int j = 0; j < grassCells[i].Count; j++)
                {
                    grassPositionSortedByCell[offset] = Matrix4x4.TRS(grassCells[i][j].Position,
                        Quaternion.FromToRotation(Vector3.up, grassCells[i][j].Normal), new Vector3(20f, 10f, 20f));
                    offset++;
                }
            }

            allInstanceTransformBuffer.SetData(grassPositionSortedByCell);
            GrassMaterial.SetBuffer("_AllInstancesTransformBuffer", allInstanceTransformBuffer);
            GrassMaterial.SetBuffer("_OnlyInstanceVisibleIDBuffer", onlyInstanceVisibleIDBuffer);

            if (argsBuffer != null)
            {
                argsBuffer.Release();
            }

            uint[] args = new uint[5] { 0, 0, 0, 0, 0 };
            argsBuffer = new ComputeBuffer(1, args.Length * sizeof(uint), ComputeBufferType.IndirectArguments);
            args[0] = (uint)GrassMesh.GetIndexCount(0);
            args[1] = (uint)AllGrassPosition.Count;
            args[2] = (uint)GrassMesh.GetIndexStart(0);
            args[3] = (uint)GrassMesh.GetBaseVertex(0);
            args[4] = 0;

            argsBuffer.SetData(args);

            grassCountCache = AllGrassPosition.Count;

            CullingComputerShader.SetBuffer(0, "_AllInstancesTransformBuffer", allInstanceTransformBuffer);
            CullingComputerShader.SetBuffer(0, "_OnlyInstanceVisibleIDBuffer", onlyInstanceVisibleIDBuffer);
        }
    }
}