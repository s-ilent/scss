using UnityEngine;
using UnityEditor;

namespace SilentCelShading.Unity
{
    public class SCSS_DetailPlacerWindow : EditorWindow
    {
        // Enums and Constants
        private enum MinimapCorner { BottomRight, BottomLeft, TopRight, TopLeft }
        private enum InteractionState { None, Panning, DraggingDecal, ScalingDecal, UsingMinimap }

        private const float MinZoom = 0.05f;
        private const float MaxZoom = 2.0f;
        private readonly string[] toolbarLabels = { "Detail 1", "Detail 2", "Detail 3", "Detail 4" };

        // Editor State
        private Material selectedMaterial;
        private int selectedDetailMapIndex = 0;
        private MinimapCorner minimapCorner = MinimapCorner.BottomRight;
        private int decalViewControlID;
        private bool maintainAspectRatio = true;

        // View State
        private Vector2 viewCenter = new Vector2(0.5f, 0.5f);
        private float zoomLevel = 1.0f;

        // Interaction State
        private InteractionState currentState = InteractionState.None;
        private DecalState activeDecal;
        private Vector2 dragStartMouseUV;
        private Vector2 dragStartDecalCenter;

        // Decal Data Wrapper
        private class DecalState
        {
            public Vector2 Center;
            public Vector2 Size;
            public readonly Texture Texture;
            private readonly Material targetMaterial;
            private readonly string stPropertyName;

            public DecalState(Material material, int detailIndex)
            {
                targetMaterial = material;
                stPropertyName = $"_DetailMap{detailIndex + 1}_ST";
                if (!targetMaterial.HasProperty(stPropertyName)) return;
                Texture = targetMaterial.GetTexture($"_DetailMap{detailIndex + 1}");
                Vector4 st = targetMaterial.GetVector(stPropertyName);
                Vector2 tiling = new Vector2(st.x, st.y);
                Vector2 offset = new Vector2(st.z, st.w);
                Size = new Vector2(Mathf.Approximately(tiling.x, 0) ? 1f : 1.0f / tiling.x, Mathf.Approximately(tiling.y, 0) ? 1f : 1.0f / tiling.y);
                Center = new Vector2(Mathf.Approximately(tiling.x, 0) ? 0.5f : (0.5f - offset.x) / tiling.x, Mathf.Approximately(tiling.y, 0) ? 0.5f : (0.5f - offset.y) / tiling.y);
            }

            public void ApplyToMaterial()
            {
                if (targetMaterial == null || !targetMaterial.HasProperty(stPropertyName)) return;
                Vector2 newTiling = new Vector2(1.0f / Size.x, 1.0f / Size.y);
                Vector2 newOffset = new Vector2(0.5f, 0.5f) - Vector2.Scale(Center, newTiling);
                Vector4 newST = new Vector4(newTiling.x, newTiling.y, newOffset.x, newOffset.y);
                if (targetMaterial.GetVector(stPropertyName) != newST)
                {
                    Undo.RecordObject(targetMaterial, "Adjust Decal Placement");
                    targetMaterial.SetVector(stPropertyName, newST);
                    EditorUtility.SetDirty(targetMaterial);
                }
            }
            public Rect GetUvRect() => new Rect(Center - Size / 2, Size);
        }

        [MenuItem("Tools/Silent's Cel Shading/Detail Map Placer")]
        public static void ShowWindow() { GetWindow<SCSS_DetailPlacerWindow>("Decal Placer"); }

        private void OnEnable() { decalViewControlID = "DecalViewControl".GetHashCode(); }

        private void OnGUI()
        {
            EditorGUILayout.BeginVertical("box");
            DrawMaterialControls();
            if (selectedMaterial == null)
            {
                EditorGUILayout.HelpBox("Please select a Material to edit its decals.", MessageType.Info);
                activeDecal = null;
            }
            else
            {
                activeDecal = new DecalState(selectedMaterial, selectedDetailMapIndex);
                DrawDecalPropertyControls();
            }
            EditorGUILayout.EndVertical();

            if (activeDecal != null)
            {
                DrawInteractivePreview();
            }

            if (currentState != InteractionState.None)
            {
                Repaint();
            }
        }

        private void DrawMaterialControls()
        {
            EditorGUILayout.LabelField("Decal Placement Tool", EditorStyles.boldLabel);
            EditorGUI.BeginChangeCheck();
            var newMaterial = (Material)EditorGUILayout.ObjectField("Target Material", selectedMaterial, typeof(Material), true);
            if (EditorGUI.EndChangeCheck() && newMaterial != selectedMaterial)
            {
                selectedMaterial = newMaterial;
                viewCenter = new Vector2(0.5f, 0.5f);
                zoomLevel = 1.0f;
            }
            minimapCorner = (MinimapCorner)EditorGUILayout.EnumPopup("Minimap Corner", minimapCorner);
            maintainAspectRatio = EditorGUILayout.Toggle("Maintain Aspect Ratio", maintainAspectRatio);
        }

        private void DrawDecalPropertyControls()
        {
            EditorGUILayout.Space();
            selectedDetailMapIndex = GUILayout.Toolbar(selectedDetailMapIndex, toolbarLabels);

            string mapPropName = $"_DetailMap{selectedDetailMapIndex + 1}";
            if (!selectedMaterial.HasProperty(mapPropName))
            {
                EditorGUILayout.HelpBox($"Shader is missing '{mapPropName}' or its corresponding '_ST' property.", MessageType.Warning);
                return;
            }

            EditorGUILayout.BeginHorizontal();
            EditorGUILayout.BeginVertical();
            EditorGUI.BeginChangeCheck();
            var newCenter = EditorGUILayout.Vector2Field("Center", activeDecal.Center);
            var newSize = EditorGUILayout.Vector2Field("Size", activeDecal.Size);
            if (EditorGUI.EndChangeCheck())
            {
                activeDecal.Center = newCenter;
                activeDecal.Size = new Vector2(Mathf.Max(0.001f, newSize.x), Mathf.Max(0.001f, newSize.y));
                activeDecal.ApplyToMaterial();
            }
            EditorGUILayout.EndVertical();

            EditorGUILayout.BeginVertical(GUILayout.Width(84));
            EditorGUILayout.LabelField("Decal Texture", GUILayout.Width(80));
            EditorGUI.BeginChangeCheck();
            var newDecalTex = (Texture)EditorGUILayout.ObjectField(GUIContent.none, activeDecal.Texture, typeof(Texture2D), false, GUILayout.Width(80), GUILayout.Height(80));
            if (EditorGUI.EndChangeCheck())
            {
                Undo.RecordObject(selectedMaterial, "Change Decal Texture");
                selectedMaterial.SetTexture(mapPropName, newDecalTex);
            }
            EditorGUILayout.EndVertical();
            EditorGUILayout.EndHorizontal();

            EditorGUILayout.Space();
            EditorGUILayout.HelpBox("LMB Drag Decal: Move | Ctrl+LMB Drag: Scale\nScroll on Decal: Scale | Scroll on BG: Zoom | RMB Drag: Pan", MessageType.Info);
        }

        private void DrawInteractivePreview()
        {
            // Get the full available area for the preview
            Rect availableRect = GUILayoutUtility.GetRect(GUIContent.none, GUIStyle.none, GUILayout.ExpandWidth(true), GUILayout.ExpandHeight(true));
            Rect previewRect = availableRect; // Default to filling the space

            // Calculate a letterboxed/pillarboxed rect if maintaining aspect ratio
            Texture mainTex = selectedMaterial.HasProperty("_MainTex") ? selectedMaterial.GetTexture("_MainTex") : null;
            if (maintainAspectRatio && mainTex != null)
            {
                float textureAspect = (float)mainTex.width / mainTex.height;
                float availableAspect = availableRect.width / availableRect.height;

                if (availableAspect > textureAspect) // Pillarbox (space is wider than texture)
                {
                    float newWidth = availableRect.height * textureAspect;
                    float xOffset = (availableRect.width - newWidth) / 2.0f;
                    previewRect = new Rect(availableRect.x + xOffset, availableRect.y, newWidth, availableRect.height);
                }
                else // Letterbox (space is taller than texture)
                {
                    float newHeight = availableRect.width / textureAspect;
                    float yOffset = (availableRect.height - newHeight) / 2.0f;
                    previewRect = new Rect(availableRect.x, availableRect.y + yOffset, availableRect.width, newHeight);
                }
            }

            HandleInput(previewRect);

            // Draw the background for the entire available area
            EditorGUI.DrawRect(availableRect, new Color(0.1f, 0.1f, 0.1f, 1));

            GUI.BeginClip(previewRect);
            if (mainTex != null)
            {
                Rect uvRect = new Rect(viewCenter.x - zoomLevel * 0.5f, viewCenter.y - zoomLevel * 0.5f, zoomLevel, zoomLevel);
                GUI.DrawTextureWithTexCoords(new Rect(0, 0, previewRect.width, previewRect.height), mainTex, uvRect);
            }
            if (activeDecal?.Texture != null)
            {
                Rect decalDrawRect = ConvertUvRectToGuiRect(activeDecal.GetUvRect(), new Rect(0, 0, previewRect.width, previewRect.height));
                GUI.DrawTexture(decalDrawRect, activeDecal.Texture);
                Handles.color = Color.yellow;
                Handles.DrawWireCube(decalDrawRect.center, decalDrawRect.size);
            }
            GUI.EndClip();

            Rect minimapRect = CalculateMinimapRect(previewRect);
            DrawMinimap(previewRect, minimapRect);
        }

        private void HandleInput(Rect previewRect)
        {
            Rect minimapRect = CalculateMinimapRect(previewRect);
            int controlID = GUIUtility.GetControlID(decalViewControlID, FocusType.Passive, previewRect);
            Event e = Event.current;

            switch (e.GetTypeForControl(controlID))
            {
                case EventType.MouseDown:
                    if (previewRect.Contains(e.mousePosition))
                    {
                        if (minimapRect.Contains(e.mousePosition) && e.button == 0)
                        {
                            GUIUtility.hotControl = controlID;
                            currentState = InteractionState.UsingMinimap;
                            UpdateViewCenterFromMinimap(e.mousePosition, minimapRect);
                            e.Use();
                        }
                        else if (e.button == 1)
                        {
                            GUIUtility.hotControl = controlID;
                            currentState = InteractionState.Panning;
                            e.Use();
                        }
                        else if (e.button == 0)
                        {
                            Vector2 mousePosInUv = ConvertGuiPointToUvPoint(e.mousePosition - previewRect.position, previewRect);
                            if (activeDecal != null && activeDecal.GetUvRect().Contains(mousePosInUv))
                            {
                                GUIUtility.hotControl = controlID;
                                currentState = e.control ? InteractionState.ScalingDecal : InteractionState.DraggingDecal;
                                dragStartMouseUV = mousePosInUv;
                                dragStartDecalCenter = activeDecal.Center;
                                e.Use();
                            }
                        }
                    }
                    break;

                case EventType.MouseUp:
                    if (GUIUtility.hotControl == controlID)
                    {
                        GUIUtility.hotControl = 0;
                        currentState = InteractionState.None;
                        e.Use();
                    }
                    break;

                case EventType.MouseDrag:
                    if (GUIUtility.hotControl == controlID)
                    {
                        switch (currentState)
                        {
                            case InteractionState.UsingMinimap:
                                UpdateViewCenterFromMinimap(e.mousePosition, minimapRect);
                                break;
                            case InteractionState.Panning:
                                Vector2 panAmount = (new Vector2(e.delta.x, -e.delta.y) / previewRect.height) * zoomLevel;
                                viewCenter -= panAmount;
                                ClampViewCenter();
                                break;
                            case InteractionState.DraggingDecal:
                                Vector2 mousePosInUv = ConvertGuiPointToUvPoint(e.mousePosition - previewRect.position, previewRect);
                                activeDecal.Center = dragStartDecalCenter + (mousePosInUv - dragStartMouseUV);
                                activeDecal.ApplyToMaterial();
                                break;
                            case InteractionState.ScalingDecal:
                                if (activeDecal?.Texture != null)
                                {
                                    // MODIFIED: Use the decal's current size aspect ratio, not the texture's.
                                    float aspect = 1.0f;
                                    if (!Mathf.Approximately(activeDecal.Size.x, 0))
                                    {
                                        aspect = activeDecal.Size.y / activeDecal.Size.x;
                                    }

                                    float delta = (e.delta.x / previewRect.width) * zoomLevel * 2;
                                    activeDecal.Size += new Vector2(delta, delta * aspect);
                                    activeDecal.Size.x = Mathf.Max(0.001f, activeDecal.Size.x);
                                    activeDecal.Size.y = Mathf.Max(0.001f, activeDecal.Size.y);
                                    activeDecal.ApplyToMaterial();
                                }
                                break;
                        }
                        e.Use();
                    }
                    break;

                case EventType.ScrollWheel:
                    if (previewRect.Contains(e.mousePosition))
                    {
                        HandleScrollWheel(e, previewRect, minimapRect);
                    }
                    break;
            }
        }

        private void HandleScrollWheel(Event e, Rect previewRect, Rect minimapRect)
        {
            if (minimapRect.Contains(e.mousePosition))
            {
                ZoomView(-e.delta.y * 0.03f, viewCenter);
            }
            else
            {
                Vector2 mousePosInUv = ConvertGuiPointToUvPoint(e.mousePosition - previewRect.position, previewRect);
                bool isOverDecal = activeDecal != null && activeDecal.GetUvRect().Contains(mousePosInUv);
                float scrollDelta = -e.delta.y * 0.03f;

                if (isOverDecal)
                {
                    float aspect = 1.0f;
                    if (!Mathf.Approximately(activeDecal.Size.x, 0))
                    {
                        aspect = activeDecal.Size.y / activeDecal.Size.x;
                    }

                    activeDecal.Size += new Vector2(scrollDelta, scrollDelta * aspect);
                    activeDecal.Size.x = Mathf.Max(0.001f, activeDecal.Size.x);
                    activeDecal.Size.y = Mathf.Max(0.001f, activeDecal.Size.y);
                    activeDecal.ApplyToMaterial();
                }
                else
                {
                    ZoomView(scrollDelta, mousePosInUv);
                }
            }
            e.Use();
        }

        private void DrawMinimap(Rect mainPreviewRect, Rect minimapRect)
        {
            bool isInteracting = currentState == InteractionState.UsingMinimap;
            bool mouseOverMinimap = minimapRect.Contains(Event.current.mousePosition);
            float alpha = mouseOverMinimap || isInteracting ? 1.0f : 0.65f;
            GUI.color = new Color(1, 1, 1, alpha);
            GUI.Box(minimapRect, "", EditorStyles.helpBox);
            Texture mainTex = selectedMaterial.HasProperty("_MainTex") ? selectedMaterial.GetTexture("_MainTex") : null;
            if (mainTex != null) GUI.DrawTexture(minimapRect, mainTex);
            Rect viewRectInMinimap = new Rect(minimapRect.x + (viewCenter.x - zoomLevel * 0.5f) * minimapRect.width, minimapRect.y + (1 - (viewCenter.y + zoomLevel * 0.5f)) * minimapRect.height, zoomLevel * minimapRect.width, zoomLevel * minimapRect.height);
            Handles.color = new Color(1, 1, 1, alpha);
            Handles.DrawWireCube(viewRectInMinimap.center, viewRectInMinimap.size);
            GUI.color = Color.white;
        }

        private void UpdateViewCenterFromMinimap(Vector2 mousePosition, Rect minimapRect)
        {
            Vector2 mouseInMap = mousePosition - minimapRect.position;
            viewCenter = new Vector2(mouseInMap.x / minimapRect.width, 1 - (mouseInMap.y / minimapRect.height));
            ClampViewCenter();
        }

        private void ZoomView(float zoomDelta, Vector2 zoomCenterUv)
        {
            float oldZoom = zoomLevel;
            zoomLevel = Mathf.Clamp(zoomLevel - zoomDelta * zoomLevel, MinZoom, MaxZoom);
            viewCenter += (zoomCenterUv - viewCenter) * (1 - zoomLevel / oldZoom);
            ClampViewCenter();
        }

        private void ClampViewCenter()
        {
            float halfExtent = zoomLevel * 0.5f;
            float min, max;

            if (zoomLevel <= 1.0f)
            {
                min = halfExtent;
                max = 1.0f - halfExtent;
            }
            else
            {
                min = 1.0f - halfExtent;
                max = halfExtent;
            }

            viewCenter.x = Mathf.Clamp(viewCenter.x, min, max);
            viewCenter.y = Mathf.Clamp(viewCenter.y, min, max);
        }

        private Rect CalculateMinimapRect(Rect mainPreviewRect)
        {
            float minimapSize = Mathf.Min(120f, mainPreviewRect.width * 0.25f);
            float margin = 5f;
            switch (minimapCorner)
            {
                case MinimapCorner.BottomLeft: return new Rect(mainPreviewRect.x + margin, mainPreviewRect.yMax - minimapSize - margin, minimapSize, minimapSize);
                case MinimapCorner.TopRight: return new Rect(mainPreviewRect.xMax - minimapSize - margin, mainPreviewRect.y + margin, minimapSize, minimapSize);
                case MinimapCorner.TopLeft: return new Rect(mainPreviewRect.x + margin, mainPreviewRect.y + margin, minimapSize, minimapSize);
                default: return new Rect(mainPreviewRect.xMax - minimapSize - margin, mainPreviewRect.yMax - minimapSize - margin, minimapSize, minimapSize);
            }
        }

        private Rect ConvertUvRectToGuiRect(Rect uvRect, Rect previewRect)
        {
            Vector2 guiBottomLeft = ConvertUvPointToGuiPoint(uvRect.position, previewRect);
            Vector2 guiTopRight = ConvertUvPointToGuiPoint(uvRect.position + uvRect.size, previewRect);
            return Rect.MinMaxRect(guiBottomLeft.x, guiTopRight.y, guiTopRight.x, guiBottomLeft.y);
        }

        private Vector2 ConvertUvPointToGuiPoint(Vector2 uvPoint, Rect previewRect)
        {
            Vector2 viewMinUV = viewCenter - Vector2.one * 0.5f * zoomLevel;
            float normalizedX = (uvPoint.x - viewMinUV.x) / zoomLevel;
            float normalizedY = (uvPoint.y - viewMinUV.y) / zoomLevel;
            return new Vector2(normalizedX * previewRect.width, (1.0f - normalizedY) * previewRect.height);
        }

        private Vector2 ConvertGuiPointToUvPoint(Vector2 guiPoint, Rect previewRect)
        {
            Vector2 viewMinUV = viewCenter - Vector2.one * 0.5f * zoomLevel;
            float normalizedX = guiPoint.x / previewRect.width;
            float normalizedY = 1.0f - (guiPoint.y / previewRect.height);
            return new Vector2(viewMinUV.x + (normalizedX * zoomLevel), viewMinUV.y + (normalizedY * zoomLevel));
        }
    }
}
