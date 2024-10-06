using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class FrustumCulling : MonoBehaviour
{
    public int instanceCount = 50000;
    public Mesh instanceMesh;
    public Material instanceMaterial;
    public int subMeshIndex = 0;

    private int cachedInstanceCount = -1;
    private int cachedSubMeshIndex = -1;
    private ComputeBuffer argsBuffer;
    private uint[] args = new uint[5] { 0, 0, 0, 0, 0 };

    public ComputeShader ComputeShader;
    private ComputeBuffer localToWorldMatrixBuffer;
    private ComputeBuffer cullResult;
    private Camera camera;
    private int kernel;
    
    void Start()
    {
        kernel = ComputeShader.FindKernel("CSMain");
        camera = Camera.main;
        cullResult = new ComputeBuffer(instanceCount, sizeof(float) * 16, ComputeBufferType.Append);
        argsBuffer = new ComputeBuffer(1, args.Length * sizeof(uint), ComputeBufferType.IndirectArguments);
        UpdateBuffers();
    }
    
    //一个点和一个法向量确定一个平面
    public static Vector4 GetPlane(Vector3 normal, Vector3 point) {
        return new Vector4(normal.x, normal.y, normal.z, -Vector3.Dot(normal, point));
    }

    //三点确定一个平面
    public static Vector4 GetPlane(Vector3 a, Vector3 b, Vector3 c) {
        Vector3 normal = Vector3.Normalize(Vector3.Cross(b - a, c - a));
        return GetPlane(normal, a);
    }
    
    public static Vector3[] GetCameraFarClipPlanePoint(Camera camera) {
        Vector3[] points = new Vector3[4];
        Transform transform = camera.transform;
        float distance = camera.farClipPlane;
        float halfFovRad = Mathf.Deg2Rad * camera.fieldOfView * 0.5f;
        float upLen = distance * Mathf.Tan(halfFovRad);
        float rightLen = upLen * camera.aspect;
        Vector3 farCenterPoint = transform.position + distance * transform.forward;
        Vector3 up = upLen * transform.up;
        Vector3 right = rightLen * transform.right;
        points[0] = farCenterPoint - up - right;//left-bottom
        points[1] = farCenterPoint - up + right;//right-bottom
        points[2] = farCenterPoint + up - right;//left-up
        points[3] = farCenterPoint + up + right;//right-up
        return points;
    }
    
    public static Vector4[] GetFrustumPlane(Camera camera) {
        Vector4[] planes = new Vector4[6];
        Transform transform = camera.transform;
        Vector3 cameraPosition = transform.position;
        Vector3[] points = GetCameraFarClipPlanePoint(camera);
        //顺时针
        planes[0] = GetPlane(cameraPosition, points[0], points[2]);//left
        planes[1] = GetPlane(cameraPosition, points[3], points[1]);//right
        planes[2] = GetPlane(cameraPosition, points[1], points[0]);//bottom
        planes[3] = GetPlane(cameraPosition, points[2], points[3]);//up
        planes[4] = GetPlane(-transform.forward, transform.position + transform.forward * camera.nearClipPlane);//near
        planes[5] = GetPlane(transform.forward, transform.position + transform.forward * camera.farClipPlane);//far
        return planes;
    }

    void Update() {
        // Update starting position buffer
        if (cachedInstanceCount != instanceCount || cachedSubMeshIndex != subMeshIndex)
            UpdateBuffers();

        Vector4[] planes = GetFrustumPlane(camera);
        ComputeShader.SetBuffer(kernel, "input", localToWorldMatrixBuffer);
        cullResult.SetCounterValue(0);
        ComputeShader.SetBuffer(kernel, "cullresult", cullResult);
        ComputeShader.SetInt("instanceCount", instanceCount);
        ComputeShader.SetVectorArray("planes", planes);
        
        ComputeShader.Dispatch(kernel, 1 + (instanceCount / 640), 1, 1);

        instanceMaterial.SetBuffer("positionBuffer", cullResult);
        
        ComputeBuffer.CopyCount(cullResult, argsBuffer, sizeof(uint));
        // Render
        Graphics.DrawMeshInstancedIndirect(instanceMesh, subMeshIndex, instanceMaterial, new Bounds(Vector3.zero, new Vector3(100.0f, 100.0f, 100.0f)), argsBuffer);
    }

    void OnGUI() {
        GUI.Label(new Rect(265, 25, 200, 30), "Instance Count: " + instanceCount.ToString());
        instanceCount = (int)GUI.HorizontalSlider(new Rect(25, 20, 200, 30), (float)instanceCount, 1.0f, 50000.0f);
    }

    void UpdateBuffers() {
        // Ensure submesh index is in range
        if (instanceMesh != null)
            subMeshIndex = Mathf.Clamp(subMeshIndex, 0, instanceMesh.subMeshCount - 1);
        
        if(localToWorldMatrixBuffer != null)
            localToWorldMatrixBuffer.Release();
        
        localToWorldMatrixBuffer = new ComputeBuffer(instanceCount, 16 * sizeof(float));
        List<Matrix4x4> localToWorldMatrixs = new List<Matrix4x4>();
        
        for (int i = 0; i < instanceCount; i++)
        {
            float angle = Random.Range(0.0f, Mathf.PI * 2.0f);
            float distance = Random.Range(20.0f, 100.0f);
            float height = Random.Range(-2.0f, 2.0f);
            float size = Random.Range(0.05f, 0.25f);
            Vector3 position = new Vector3(Mathf.Sin(angle) * distance, height, Mathf.Cos(angle) * distance);
            localToWorldMatrixs.Add(Matrix4x4.TRS(position, Quaternion.identity, new Vector3(size, size, size)));
        }
        
        localToWorldMatrixBuffer.SetData(localToWorldMatrixs);

        // Indirect args
        if (instanceMesh != null) {
            args[0] = (uint)instanceMesh.GetIndexCount(subMeshIndex);
            args[1] = (uint)instanceCount;
            args[2] = (uint)instanceMesh.GetIndexStart(subMeshIndex);
            args[3] = (uint)instanceMesh.GetBaseVertex(subMeshIndex);
        }
        else
        {
            args[0] = args[1] = args[2] = args[3] = 0;
        }
        
        argsBuffer.SetData(args);

        cachedInstanceCount = instanceCount;
        cachedSubMeshIndex = subMeshIndex;
    }

    void OnDisable() {
        localToWorldMatrixBuffer?.Release();
        localToWorldMatrixBuffer = null;

        cullResult?.Release();
        cullResult = null;
        
        if (argsBuffer != null)
            argsBuffer.Release();
        argsBuffer = null;
    }
}
