using UnityEngine;
[ExecuteInEditMode]
public class SetInteractiveMaskWorldPos : MonoBehaviour
{
    public Material Material;
    void Update()
    {
        Material.SetVector("_ObjWorldPos", new Vector4(transform.position.x, transform.position.y, transform.position.z, transform.localScale.x));
    }
}
