using System;
using System.Collections;
using System.Collections.Generic;
using System.IO;
using UnityEditor;
using UnityEngine;

[CustomEditor(typeof(MeshPainter))]
[CanEditMultipleObjects]
public class MeshPainterStyle : Editor
{
    bool isPaint;
    float brushSize = 16f;
    float brushStronger = 0.5f;
    Texture[] brushTexs;
    
    int selBrush = 0;
    int selTex = 0;
    bool ToggleF = false;
    
    int brushSizePercent;
    private static readonly int DataTex = Shader.PropertyToID("_DataTex");
    
    private Texture2D furDataTex;
    
    private void OnSceneGUI()
    {
        if (isPaint)
        {
            Painter();
        }
    }
    
    public override void OnInspectorGUI()
    {
        if (Check())
        {
            GUIStyle boolBtnOn = new GUIStyle(GUI.skin.GetStyle("Button"));//得到Button样式
    
            GUILayout.BeginHorizontal();
            GUILayout.FlexibleSpace();
            isPaint = GUILayout.Toggle(isPaint, EditorGUIUtility.IconContent("EditCollider"), boolBtnOn, GUILayout.Width(35), GUILayout.Height(25));//编辑模式开关
            GUILayout.FlexibleSpace();
            GUILayout.EndHorizontal();
            
            brushSize = (int)EditorGUILayout.Slider("Brush Size", brushSize, 1, 36);//笔刷大小
            brushStronger = EditorGUILayout.Slider("Brush Stronger", brushStronger, 0, 1f);//笔刷强度
            
            InitBrush();
            GUILayout.BeginHorizontal();
            GUILayout.FlexibleSpace();
            GUILayout.BeginHorizontal("box", GUILayout.Width(318));
            selBrush = GUILayout.SelectionGrid(selBrush, brushTexs, 5, "gridlist", GUILayout.Width(340),
                GUILayout.Height(340));
            GUILayout.EndHorizontal();
            GUILayout.FlexibleSpace();
            GUILayout.EndHorizontal();
        }
    }
    
    private bool Check()
    {
        bool passCheck = false;
        Transform select = Selection.activeTransform;
        if (select.GetComponent<MeshRenderer>().sharedMaterial.shader == Shader.Find("Fur/BaseFur"))
        {
            Texture furDataTex = select.GetComponent<MeshRenderer>().sharedMaterial.GetTexture(DataTex);
            if (furDataTex == null)
            {
                EditorGUILayout.HelpBox("当前材质不存在DataTex", MessageType.Error);
                if (GUILayout.Button("生成DataTex"))
                {
                    CreateFurDataTex();
                }
            }
            else
            {
                EditorGUILayout.HelpBox("当前绘制的是毛发的DataTex", MessageType.Info);
                passCheck = true;
            }
        }
    
        return passCheck;
    }
    
    private void CreateFurDataTex()
    {
        string furDataTexName = string.Empty;
        string furDataTexFolder = "Assets/Textures/FurDataTex/";
        Texture2D furDataTex = new Texture2D(512, 512, TextureFormat.ARGB32, false, true);
        
        Color[] colorBase = new Color[512 * 512];
        for(int i = 0; i< colorBase.Length; i++)
        {
            colorBase[i] = Color.clear;
        }
        furDataTex.SetPixels(colorBase);
        
        for (int index = 1; index <= 100; index++)
        {
            if (!File.Exists(furDataTexFolder + Selection.activeTransform.name + ".png"))
            {
                furDataTexName = Selection.activeTransform.name;
                break;
            }
            string next = Selection.activeTransform.name + "_" + index;
            if (!File.Exists(furDataTexFolder + next + ".png"))
            {
                furDataTexName = next;
                break;
            }
        }
        string path = furDataTexFolder + furDataTexName + ".png";
        byte[] bytes = furDataTex.EncodeToPNG();
        File.WriteAllBytes(path, bytes);
    
        AssetDatabase.ImportAsset(path, ImportAssetOptions.ForceUpdate);
        TextureImporter textureIm = AssetImporter.GetAtPath(path) as TextureImporter;
        textureIm.textureCompression = TextureImporterCompression.Uncompressed;
        textureIm.isReadable = true;
        textureIm.mipmapEnabled = false;
        textureIm.wrapMode = TextureWrapMode.Clamp;
        textureIm.sRGBTexture = false;
        AssetDatabase.ImportAsset(path, ImportAssetOptions.ForceUpdate);
    
        SetFurDataTex(path);
    }
    
    private void SetFurDataTex(string path)
    {
        Texture2D furDataTex = (Texture2D)AssetDatabase.LoadAssetAtPath(path, typeof(Texture2D));
        Selection.activeTransform.gameObject.GetComponent<MeshRenderer>().sharedMaterial.SetTexture(DataTex, furDataTex);
    }
    
    private void InitBrush()
    {
        string brushFolder = "Assets/Scenes/Tool/MeshPainter/Editor/";
        List<Texture> BrushList = new List<Texture>();
        Texture Brush;
        int BrushNum = 1;
        do
        {
            Brush = (Texture)AssetDatabase.LoadAssetAtPath(brushFolder + "Brushes/Brush" + BrushNum + ".png", typeof(Texture));
    
            if (Brush)
            {
                BrushList.Add(Brush);
            }
            BrushNum++;
        } while (Brush);
        brushTexs = BrushList.ToArray();
    }
    
    private void Painter()
    {
        Transform currentSelect = Selection.activeTransform;
        MeshFilter meshFilter = currentSelect.GetComponent<MeshFilter>();
        float orthographicSize = (brushSize * currentSelect.localScale.x) * (meshFilter.sharedMesh.bounds.size.x / 200);
        furDataTex = currentSelect.gameObject.GetComponent<MeshRenderer>().sharedMaterial.GetTexture(DataTex) as Texture2D;
        brushSizePercent = (int) Mathf.Round(brushSize * furDataTex.width / 100);
        Event e = Event.current;
        HandleUtility.AddDefaultControl(0);
        RaycastHit raycastHit = new RaycastHit();
        Ray terrain = HandleUtility.GUIPointToWorldRay(e.mousePosition);
        if (Physics.Raycast(terrain, out raycastHit, Mathf.Infinity,
            1 << LayerMask.NameToLayer("Fur")))
        {
            Handles.color = new Color(1f, 1f, 0f, 1f);
            Handles.DrawWireDisc(raycastHit.point, raycastHit.normal, orthographicSize);
    
            //鼠标点击或按下并拖动进行绘制
            if ((e.type == EventType.MouseDrag && e.alt == false && e.control == false && e.shift == false &&
                 e.button == 0) || (e.type == EventType.MouseDown && e.shift == false && e.alt == false &&
                                    e.control == false && e.button == 0 && ToggleF == false))
            {
                //选择绘制的通道
                Color targetColor = new Color(1f, 0f, 0f, 0f);

                Vector2 pixelUV = raycastHit.textureCoord;
                int puX = Mathf.FloorToInt(pixelUV.x * furDataTex.width);
                int puY = Mathf.FloorToInt(pixelUV.y * furDataTex.height);
                int x = Mathf.Clamp(puX - brushSizePercent / 2, 0, furDataTex.width - 1);
                int y = Mathf.Clamp(puY - brushSizePercent / 2, 0, furDataTex.height - 1);
                int width = Mathf.Clamp((puX + brushSizePercent / 2), 0, furDataTex.width) - x;
                int height = Mathf.Clamp((puY + brushSizePercent / 2), 0, furDataTex.height) - y;
                Color[] terrainBay = furDataTex.GetPixels(x, y, width, height, 0);
    
                Texture2D TBrush = brushTexs[selBrush] as Texture2D;
                float[] brushAlpha = new float[brushSizePercent * brushSizePercent];
                
                for (int i = 0; i < brushSizePercent; i++)
                {
                    for (int j = 0; j < brushSizePercent; j++)
                    {
                        brushAlpha[j * brushSizePercent + i] = TBrush.GetPixelBilinear(((float)i) / brushSizePercent, ((float)j) / brushSizePercent).r;
                    }
                }
                
                for (int i = 0; i < height; i++)
                {
                    for (int j = 0; j < width; j++)
                    {
                        int index = (i * width) + j;
                        float Stronger =
                            brushAlpha[
                                Mathf.Clamp((y + i) - (puY - brushSizePercent / 2), 0, brushSizePercent - 1) *
                                brushSizePercent + Mathf.Clamp((x + j) - (puX - brushSizePercent / 2), 0,
                                    brushSizePercent - 1)] * brushStronger;
    
                        terrainBay[index] = Color.Lerp(terrainBay[index], targetColor, Stronger);
                    }
                }
                Undo.RegisterCompleteObjectUndo(furDataTex, "meshPaint");
    
                furDataTex.SetPixels(x, y, width, height, terrainBay, 0);
                furDataTex.Apply();
                ToggleF = true;
            }
            else if (e.type == EventType.MouseUp && e.alt == false && e.button == 0 && ToggleF == true)
            {
    
                SaveTexture();
                ToggleF = false;
            }
        }
    }
    
    private void SaveTexture()
    {
        var path = AssetDatabase.GetAssetPath(furDataTex);
        var bytes = furDataTex.EncodeToPNG();
        File.WriteAllBytes(path, bytes);
        // AssetDatabase.ImportAsset(path, ImportAssetOptions.ForceUpdate);//刷新
    }
}

