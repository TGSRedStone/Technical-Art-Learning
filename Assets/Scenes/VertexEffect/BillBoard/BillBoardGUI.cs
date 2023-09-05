using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEditor;

public class BillBoardGUI : ShaderGUI
{
    private MaterialProperty billBoardRotation = null;
    private MaterialProperty billBoardScale = null;
    private Material material;

    private enum AxisLock
    {
        None,
        XAxis,
        YAxis,
        ZAxis
    }

    private AxisLock axisLock;

    private void SetAxisLock(AxisLock axis)
    {
        SetKeyword(AxisLock.None.ToString(), axis == AxisLock.None);
        SetKeyword(AxisLock.XAxis.ToString(), axis == AxisLock.XAxis);
        SetKeyword(AxisLock.YAxis.ToString(), axis == AxisLock.YAxis);
        SetKeyword(AxisLock.ZAxis.ToString(), axis == AxisLock.ZAxis);
    }

    private bool IsKeywordEnabled(string keyword)
    {
        return material.IsKeywordEnabled(keyword);
    }

    private void SetKeyword(string keyword, bool state)
    {
        if (state)
        {
            material.EnableKeyword(keyword);
        }
        else
        {
            material.DisableKeyword(keyword);
        }
    }

    public override void OnGUI(MaterialEditor materialEditor, MaterialProperty[] properties)
    {
        material = materialEditor.target as Material;

        billBoardRotation = FindProperty("_BillboardRotation", properties);
        billBoardScale = FindProperty("_BillboardScale", properties);

        if (IsKeywordEnabled(AxisLock.None.ToString()))
        {
            axisLock = AxisLock.None;
        }
        else if (IsKeywordEnabled(AxisLock.XAxis.ToString()))
        {
            axisLock = AxisLock.XAxis;
        }
        else if (IsKeywordEnabled(AxisLock.YAxis.ToString()))
        {
            axisLock = AxisLock.YAxis;
        }
        else if (IsKeywordEnabled(AxisLock.ZAxis.ToString()))
        {
            axisLock = AxisLock.ZAxis;
        }
        else
        {
            axisLock = AxisLock.None;
        }

        materialEditor.PropertiesDefaultGUI(properties);

        Vector3 eulerAngles =
            new Vector3(
                billBoardRotation.vectorValue.x,
                billBoardRotation.vectorValue.y,
                billBoardRotation.vectorValue.z
            );
        Vector3 scales =
            new Vector3(
                billBoardScale.vectorValue.x,
                billBoardScale.vectorValue.y,
                billBoardScale.vectorValue.z
            );

        float scaleZ = billBoardScale.vectorValue.w;

        EditorGUI.BeginChangeCheck();
        {
            EditorGUIUtility.labelWidth = 0f;
            eulerAngles = EditorGUILayout.Vector3Field("Rotation", eulerAngles);
            scales = EditorGUILayout.Vector3Field("Scale", scales);

            scaleZ = EditorGUILayout.Slider("scaleZ", scaleZ, 0, 1);
            EditorGUILayout.Space();
            GUILayout.BeginHorizontal();
            {
                EditorGUILayout.Space();
                if (GUILayout.Button("Reset", GUILayout.Width(80)))
                {
                    scales = Vector3.one;
                    eulerAngles = Vector3.zero;
                    scaleZ = 0;
                }
            }
            GUILayout.EndHorizontal();
            EditorGUILayout.Space();
            axisLock = (AxisLock)EditorGUILayout.EnumPopup("AxisLock", axisLock);
            materialEditor.SetDefaultGUIWidths();
        }
        if (EditorGUI.EndChangeCheck())
        {
            eulerAngles = WrapAngle(eulerAngles);
            billBoardRotation.vectorValue = new Vector4(eulerAngles.x, eulerAngles.y, eulerAngles.z, 0);
            billBoardScale.vectorValue = new Vector4(scales.x, scales.y, scales.z, scaleZ);
            SetAxisLock(axisLock);
        }

        Quaternion rot = Quaternion.Euler(eulerAngles);
        Matrix4x4 m = Matrix4x4.TRS(Vector3.zero, rot, scales);

        if (material != null)
        {
            material.SetVector("_BillboardMatrix0", m.GetColumn(0));
            material.SetVector("_BillboardMatrix1", m.GetColumn(1));
            material.SetVector("_BillboardMatrix2", -m.GetColumn(2) * scaleZ);
        }
    }

    private float WrapAngle(float angle)
    {
        while (angle > 180f) angle -= 360f;
        while (angle < -180f) angle += 360f;
        return angle;
    }

    private Vector3 WrapAngle(Vector3 angles)
    {
        angles =
            new Vector3(
                WrapAngle(angles.x),
                WrapAngle(angles.y),
                WrapAngle(angles.z)
            );
        return angles;
    }
}