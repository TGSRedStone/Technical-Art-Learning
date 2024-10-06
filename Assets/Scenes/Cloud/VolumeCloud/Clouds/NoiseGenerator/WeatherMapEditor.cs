using UnityEditor;
using UnityEngine;

namespace Scenes.Cloud.VolumeCloud.Clouds.NoiseGenerator
{
    [CustomEditor(typeof(WeatherMapGenerator))]
    public class WeatherMapEditor : Editor
    {
        WeatherMapGenerator weather;
        Editor noiseSettingsEditor;

        public override void OnInspectorGUI()
        {
            DrawDefaultInspector();
        
            if (GUILayout.Button("Generate"))
            {
                weather.GenerateWeatherMap();
            }
        
            if (GUILayout.Button("Save"))
            {
                weather.Save(weather.weatherMap, "WeatherMap");
            }

            if (weather.weatherMapSettings != null)
            {
                DrawSettingsEditor(weather.weatherMapSettings, ref noiseSettingsEditor);
            }
        }


        private void DrawSettingsEditor(Object settings, ref Editor editor)
        {
            if (settings != null)
            {
                EditorGUILayout.InspectorTitlebar(true, settings);
                using (var check = new EditorGUI.ChangeCheckScope())
                {
                    CreateCachedEditor(settings, null, ref editor);
                    editor.OnInspectorGUI();
                }
            }
        }

        void OnEnable()
        {
            weather = (WeatherMapGenerator)target;
        }
    }
}