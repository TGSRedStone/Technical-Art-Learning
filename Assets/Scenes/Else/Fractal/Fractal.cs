//reference:https://catlikecoding.com/
using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class Fractal : MonoBehaviour
{
    [SerializeField, Range(1, 8)] private int depth = 4;
    
    // Fractal CreateChild (Vector3 direction, Quaternion rotation)
    // {
    //     Fractal child = Instantiate(this);
    //     child.depth = depth - 1;
    //     child.transform.localPosition = 0.75f * direction;
    //     child.transform.localRotation = rotation;
    //     child.transform.localScale = 0.5f * Vector3.one;
    //     return child;
    // }
    //
    // void Start()
    // {
    //     name = "Fractal " + depth;
    //     if (depth <= 1)
    //     {
    //         return;
    //     }
    //     
    //     Fractal childA = CreateChild(Vector3.up, Quaternion.identity);
    //     Fractal childB = CreateChild(Vector3.right, Quaternion.Euler(0f, 0f, -90f));
    //     Fractal childC = CreateChild(Vector3.left, Quaternion.Euler(0f, 0f, 90f));
    //     Fractal childD = CreateChild(Vector3.forward, Quaternion.Euler(90f, 0f, 0f));
    //     Fractal childE = CreateChild(Vector3.back, Quaternion.Euler(-90f, 0f, 0f));
    //
    //     childA.transform.SetParent(transform, false);
    //     childB.transform.SetParent(transform, false);
    //     childC.transform.SetParent(transform, false);
    //     childD.transform.SetParent(transform, false);
    //     childE.transform.SetParent(transform, false);
    // }
    //
    // void Update ()
    // {
    //     transform.Rotate(0f, 22.5f * Time.deltaTime, 0f);
    // }
    
    [SerializeField]
    Mesh mesh;

    [SerializeField]
    Material material;

    struct FractalPart
    {
        public Vector3 direction;
        public Quaternion rotation;
        public Transform transform;
    }
    
    FractalPart[][] parts;

    private static Vector3[] directions =
    {
        Vector3.up, Vector3.right, Vector3.left, Vector3.forward, Vector3.back
    };

    private static Quaternion[] rotations =
    {
        Quaternion.identity,
        Quaternion.Euler(0f, 0f, -90f), Quaternion.Euler(0f, 0f, 90f),
        Quaternion.Euler(90f, 0f, 0f), Quaternion.Euler(-90f, 0f, 0f)
    };

    FractalPart CreatePart(int levelIndex, int childIndex, float scale)
    {
        var go = new GameObject("Fractal Part" + levelIndex + " C" + childIndex);
        go.transform.localScale = scale * Vector3.one;
        go.transform.SetParent(transform, false);
        go.AddComponent<MeshFilter>().mesh = mesh;
        go.AddComponent<MeshRenderer>().material = material;
        
        return new FractalPart
        {
            direction = directions[childIndex],
            rotation = rotations[childIndex],
            transform = go.transform
        };
    }
    
    void Awake ()
    {
        parts = new FractalPart[depth][];
        for (int i = 0, length = 1; i < parts.Length; i++, length *= 5)
        {
            parts[i] = new FractalPart[length];
        }
        float scale = 1f;
        parts[0][0] = CreatePart(0, 0, scale);
        for (int li = 1; li < parts.Length; li++)
        {
            scale *= 0.5f;
            FractalPart[] levelParts = parts[li];
            for (int fpi = 0; fpi < levelParts.Length; fpi += 5)
            {
                for (int ci = 0; ci < 5; ci++)
                {
                    levelParts[fpi + ci] = CreatePart(li, ci, scale);
                }
            }
        }
    }
    
    void Update ()
    {
        Quaternion deltaRotation = Quaternion.Euler(0f, 22.5f * Time.deltaTime, 0f);
        FractalPart rootPart = parts[0][0];
        rootPart.rotation *= deltaRotation;
        rootPart.transform.localRotation = rootPart.rotation;
        parts[0][0] = rootPart;
        
        for (int li = 1; li < parts.Length; li++)
        {
            FractalPart[] parentParts = parts[li - 1];
            FractalPart[] levelParts = parts[li];
            for (int fpi = 0; fpi < levelParts.Length; fpi++)
            {
                Transform parentTransform = parentParts[fpi / 5].transform;
                FractalPart part = levelParts[fpi];
                part.rotation *= deltaRotation;
                part.transform.localRotation = parentTransform.localRotation * part.rotation;
                part.transform.localPosition = parentTransform.localPosition + parentTransform.localRotation * (1.5f * part.transform.localScale.x * part.direction);
                levelParts[fpi] = part;
            }
        }
    }
}