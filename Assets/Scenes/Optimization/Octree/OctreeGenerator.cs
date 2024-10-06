using UnityEngine;

namespace Scenes.Optimization.Octree
{
    public class OctreeGenerator : MonoBehaviour
    {
        public GameObject[] Objects;
        public float MinNodeSize = 1f;
        private Octree octree;

        private void Awake()
        {
            octree = new Octree(Objects, MinNodeSize);
        }

        private void OnDrawGizmos()
        {
            if (!Application.isPlaying)
            {
                return;
            }
            
            Gizmos.color = Color.green;
            Gizmos.DrawWireCube(octree.Bounds.center, octree.Bounds.size);
            octree.Root.DrawNode();
        }
    }
}