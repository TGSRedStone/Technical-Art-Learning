using UnityEditor;
using UnityEngine;

namespace Scenes.Cloud.VolumeCloud.Clouds.NoiseGenerator
{
    [CustomEditor(typeof(NoiseGenerator))]
    public class NoiseGeneratorEditor : Editor
    {
        private NoiseGenerator _noiseGenerator;
        private Editor _noiseSettingsEditor;

        public override void OnInspectorGUI()
        {
            _noiseGenerator = target as NoiseGenerator;

            DrawDefaultInspector();

            if (GUILayout.Button("Generate"))
            {
                _noiseGenerator.Generate();
            }

            if (GUILayout.Button("Save"))
            {
                _noiseGenerator.Save(_noiseGenerator.CurrentRenderTexture, _noiseGenerator.CurrentRenderTextureName);
            }

            if (_noiseGenerator.CurrentNoiseSettings != null)
            {
                DrawNoiseSettings(_noiseGenerator.CurrentNoiseSettings, ref _noiseSettingsEditor);
            }
        }

        private void DrawNoiseSettings(Object settings, ref Editor editor)
        {
            EditorGUILayout.InspectorTitlebar(true, settings);
            using (var check = new EditorGUI.ChangeCheckScope())
            {
                CreateCachedEditor(settings, null, ref editor);
                editor.OnInspectorGUI();
                if (check.changed)
                {
                    _noiseGenerator.Generate();
                }
            }
        }

    }
}
