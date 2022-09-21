using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class GrassGenerator : MonoBehaviour
{
    public Mesh GrassMesh;
    public int SubMeshIndex = 0;
    public Material GrassMaterial;
    public int GrassCountPerRaw = 300;//每行草的数量
    // public DepthTextureGenerator depthTextureGenerator;
    public ComputeShader Compute;//剔除的ComputeShader

    private int grassCount;
    private int kernel;
    private Camera mainCamera;

    ComputeBuffer argsBuffer;
    ComputeBuffer grassMatrixBuffer;//所有草的世界坐标矩阵
    ComputeBuffer cullResultBuffer;//剔除后的结果

    uint[] args = new uint[5] { 0, 0, 0, 0, 0 };

    int cullResultBufferId, vpMatrixId, positionBufferId, hizTextureId;
    
    public DepthTex DepthTexGenerator;

    private void Start()
    {
        grassCount = GrassCountPerRaw * GrassCountPerRaw;
        mainCamera = Camera.main;

        if(GrassMesh != null) {
            args[0] = GrassMesh.GetIndexCount(SubMeshIndex);
            args[2] = GrassMesh.GetIndexStart(SubMeshIndex);
            args[3] = GrassMesh.GetBaseVertex(SubMeshIndex);
        }

        InitComputeBuffer();
        InitGrassPosition();
        InitComputeShader();
    }
    
    private void InitComputeShader()
    {
        kernel = Compute.FindKernel("CSMain");
        Compute.SetInt("grassCount", grassCount);
        Compute.SetInt("depthTextureSize", DepthTexGenerator.settings.size);
        Compute.SetBool("isOpenGL", Camera.main.projectionMatrix.Equals(GL.GetGPUProjectionMatrix(Camera.main.projectionMatrix, false)));
        Compute.SetBuffer(kernel, "grassMatrixBuffer", grassMatrixBuffer);
        
        cullResultBufferId = Shader.PropertyToID("cullResultBuffer");
        vpMatrixId = Shader.PropertyToID("vpMatrix");
        hizTextureId = Shader.PropertyToID("hizTexture");
        positionBufferId = Shader.PropertyToID("positionBuffer");
    }
    
    private void InitComputeBuffer()
    {
        if(grassMatrixBuffer != null) return;
        argsBuffer = new ComputeBuffer(1, args.Length * sizeof(uint), ComputeBufferType.IndirectArguments);
        argsBuffer.SetData(args);
        grassMatrixBuffer = new ComputeBuffer(grassCount, sizeof(float) * 16);
        cullResultBuffer = new ComputeBuffer(grassCount, sizeof(float) * 16, ComputeBufferType.Append);
    }
    
    float GetGroundHeight(Vector2 xz) {
        RaycastHit hit;
        if(Physics.Raycast(new Vector3(xz.x, 50, xz.y), Vector3.down, out hit, 60)) {
            return 50 - hit.distance;
        }
        return 0;
    }

    private void Update()
    {
        Compute.SetTexture(kernel, hizTextureId, DepthTexGenerator.settings.depth);
        Compute.SetMatrix(vpMatrixId, GL.GetGPUProjectionMatrix(mainCamera.projectionMatrix, false) * mainCamera.worldToCameraMatrix);
        cullResultBuffer.SetCounterValue(0);
        Compute.SetBuffer(kernel, cullResultBufferId, cullResultBuffer);
        Compute.Dispatch(kernel, 1 + grassCount / 640, 1, 1);
        GrassMaterial.SetBuffer(positionBufferId, cullResultBuffer);

        //获取实际要渲染的数量
        ComputeBuffer.CopyCount(cullResultBuffer, argsBuffer, sizeof(uint));
        Graphics.DrawMeshInstancedIndirect(GrassMesh, SubMeshIndex, GrassMaterial, new Bounds(Vector3.zero, new Vector3(100.0f, 100.0f, 100.0f)), argsBuffer);
    }
    
    private void InitGrassPosition()
    {
        const int padding = 1;
        int width = (100 - padding * 2);
        int widthStart = -width / 2;
        float step = (float)width / GrassCountPerRaw;
        Matrix4x4[] grassMatrixs = new Matrix4x4[grassCount];
        for(int i = 0; i < GrassCountPerRaw; i++) {
            for(int j = 0; j < GrassCountPerRaw; j++) {
                Vector2 xz = new Vector2(widthStart + step * i, widthStart + step * j);
                Vector3 position = new Vector3(xz.x, GetGroundHeight(xz), xz.y);
                grassMatrixs[i * GrassCountPerRaw + j] = Matrix4x4.TRS(position, Quaternion.identity, Vector3.one);
            }
        }
        grassMatrixBuffer.SetData(grassMatrixs);
    }
    
    void OnDisable() {
        grassMatrixBuffer?.Release();
        grassMatrixBuffer = null;

        cullResultBuffer?.Release();
        cullResultBuffer = null;

        argsBuffer?.Release();
        argsBuffer = null;
    }

}
