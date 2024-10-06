using System.Linq;
using UnityEngine;
using UnityEngine.Rendering.Universal;

namespace Scenes.Cloud.VolumeCloud.Clouds
{
    [ExecuteInEditMode]
    public class CloudBounds : MonoBehaviour
    {
        [SerializeField] private ForwardRendererData universalRendererData;
        public Color colour = Color.green;
        public bool displayOutline = true;

        private void Start()
        {
            universalRendererData.rendererFeatures.OfType<CloudRenderPassFeature>().FirstOrDefault()!.settings.transform =
                transform;
        }

        private void OnEnable()
        {
            universalRendererData.rendererFeatures.OfType<CloudRenderPassFeature>().FirstOrDefault()!.settings.transform =
                transform;
        }

        private void OnDrawGizmosSelected ()
        {
            if (!displayOutline) return;
            Gizmos.color = colour;
            Gizmos.DrawWireCube (transform.position, transform.localScale);
        }
    }
}
