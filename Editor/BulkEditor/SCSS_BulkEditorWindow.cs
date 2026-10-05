using System.Collections.Generic;
using UnityEditor;
using UnityEngine;
using System.Linq;

namespace SilentCelShading.Unity.BulkEditor
{
    public class SCSS_BulkEditorWindow : EditorWindow
    {
        // Layout Constants
        private const float MIN_LEFT_PANE_WIDTH = 200f;
        private const float MIN_RIGHT_PANE_WIDTH = 350f;
        private const float SPLITTER_WIDTH = 4f;

        // State
        private float leftPaneWidth = 250f;
        private bool isResizingSplitter = false;
        private Vector2 leftScroll;
        private Vector2 rightScroll;

        // Collection Settings
        private bool includeInactive = true;
        private bool includeHidden = true;
        private bool pendingAutoCollect = false;

        // Data
        private List<SCSSMaterialEntry> materialEntries = new List<SCSSMaterialEntry>();
        private SCSS_BulkEditorHost inspectorHost;
        private Dictionary<string, bool> applyMask = new Dictionary<string, bool>();

        [MenuItem("Tools/Silent's Cel Shading/Bulk Material Editor")]
        public static void ShowWindow()
        {
            var window = GetWindow<SCSS_BulkEditorWindow>("SCSS Bulk Editor");
            window.minSize = new Vector2(600f, 400f);
        }

        private void OnEnable()
        {
            RequestAutoCollect();
        }

        private void OnDisable()
        {
            if (inspectorHost != null) inspectorHost.Dispose();
        }

        private void OnSelectionChange()
        {
            RequestAutoCollect();
        }

        private void Update()
        {
            if (pendingAutoCollect)
            {
                pendingAutoCollect = false;
                CollectMaterials();
                Repaint();
            }
        }

        private void RequestAutoCollect()
        {
            pendingAutoCollect = true;
        }

        private void CollectMaterials()
        {
            materialEntries = SCSS_BulkEditorScanner.CollectMaterials(Selection.gameObjects, includeInactive, includeHidden);

            // Initialize Host using the first selected material
            if (inspectorHost == null && materialEntries.Count > 0)
            {
                inspectorHost = new SCSS_BulkEditorHost(materialEntries[0].Material);
            }
            // Clean up if no materials are found
            else if (materialEntries.Count == 0 && inspectorHost != null)
            {
                inspectorHost.Dispose();
                inspectorHost = null;
            }
        }

        private void OnGUI()
        {
            DrawToolbar();

            // Clamp left pane width based on window size
            float maxLeftWidth = position.width - MIN_RIGHT_PANE_WIDTH - SPLITTER_WIDTH;
            leftPaneWidth = Mathf.Clamp(leftPaneWidth, MIN_LEFT_PANE_WIDTH, Mathf.Max(MIN_LEFT_PANE_WIDTH, maxLeftWidth));

            EditorGUILayout.BeginHorizontal();

            DrawLeftPane();
            DrawSplitter();
            DrawRightPane();

            EditorGUILayout.EndHorizontal();

            DrawStatusBar();
        }

        private void DrawToolbar()
        {
            using (new EditorGUILayout.HorizontalScope(EditorStyles.toolbar))
            {
                EditorGUI.BeginChangeCheck();
                includeInactive = GUILayout.Toggle(includeInactive, "Include Inactive", EditorStyles.toolbarButton);
                includeHidden = GUILayout.Toggle(includeHidden, "Include Hidden", EditorStyles.toolbarButton);
                if (EditorGUI.EndChangeCheck())
                {
                    RequestAutoCollect();
                }

                GUILayout.FlexibleSpace();
                if (GUILayout.Button("Refresh", EditorStyles.toolbarButton))
                {
                    RequestAutoCollect();
                }
            }
        }

        private void DrawLeftPane()
        {
            // Capture the start of the area
            using (var scope = new EditorGUILayout.VerticalScope(GUILayout.Width(leftPaneWidth), GUILayout.ExpandHeight(true)))
            {
                EditorGUILayout.LabelField($"Materials ({materialEntries.Count})", EditorStyles.boldLabel);
                EditorGUILayout.Space(2f);

                leftScroll = EditorGUILayout.BeginScrollView(leftScroll);

                if (materialEntries.Count == 0)
                {
                    EditorGUILayout.HelpBox("Select GameObjects in the Hierarchy.", MessageType.Info);
                }
                else
                {
                    foreach (var entry in materialEntries)
                    {
                        DrawMaterialEntry(entry);
                    }
                }

                EditorGUILayout.EndScrollView();

                // Use the scope's rect for the context menu check
                Rect listRect = scope.rect;

                if (Event.current.type == EventType.ContextClick && listRect.Contains(Event.current.mousePosition))
                {
                    GenericMenu menu = new GenericMenu();
                    menu.AddItem(new GUIContent("Select All"), false, () => { foreach (var e in materialEntries) e.IsSelected = true; });
                    menu.AddItem(new GUIContent("Deselect All"), false, () => { foreach (var e in materialEntries) e.IsSelected = false; });
                    menu.AddItem(new GUIContent("Invert Selection"), false, () => { foreach (var e in materialEntries) e.IsSelected = !e.IsSelected; });
                    menu.ShowAsContext();
                    Event.current.Use();
                }
            }
        }

        private void DrawMaterialEntry(SCSSMaterialEntry entry)
        {
            using (new EditorGUILayout.VerticalScope(EditorStyles.helpBox))
            {
                using (new EditorGUILayout.HorizontalScope())
                {
                    // Selection Toggle
                    entry.IsSelected = EditorGUILayout.Toggle(entry.IsSelected, GUILayout.Width(16f));

                    // Material Name (Click to Ping in Project)
                    GUIStyle linkStyle = new GUIStyle(EditorStyles.linkLabel) { alignment = TextAnchor.MiddleLeft };
                    if (GUILayout.Button(entry.DisplayName, linkStyle))
                    {
                        EditorGUIUtility.PingObject(entry.Material);
                    }

                    GUILayout.FlexibleSpace();
                    EditorGUILayout.LabelField(entry.Usages.Count.ToString(), EditorStyles.miniLabel, GUILayout.Width(24f));
                }

                if (entry.Usages.Count > 0)
                {
                    entry.IsExpanded = EditorGUILayout.Foldout(entry.IsExpanded, "Assigned Renderers", true);
                    if (entry.IsExpanded)
                    {
                        EditorGUI.indentLevel++;
                        foreach (var usage in entry.Usages)
                        {
                            EditorGUILayout.LabelField($"{usage.DisplayPath} [Slot {usage.SlotIndex}]", EditorStyles.miniLabel);
                        }
                        EditorGUI.indentLevel--;
                    }
                }
            }
            EditorGUILayout.Space(2f);
        }

        private void DrawSplitter()
        {
            Rect splitterRect = GUILayoutUtility.GetRect(GUIContent.none, GUIStyle.none, GUILayout.Width(SPLITTER_WIDTH), GUILayout.ExpandHeight(true));
            EditorGUIUtility.AddCursorRect(splitterRect, MouseCursor.ResizeHorizontal);

            if (Event.current.type == EventType.Repaint)
            {
                Color splitterColor = EditorGUIUtility.isProSkin ? new Color(0.15f, 0.15f, 0.15f) : new Color(0.6f, 0.6f, 0.6f);
                EditorGUI.DrawRect(splitterRect, splitterColor);
            }

            switch (Event.current.type)
            {
                case EventType.MouseDown:
                    if (splitterRect.Contains(Event.current.mousePosition))
                    {
                        isResizingSplitter = true;
                        Event.current.Use();
                    }
                    break;
                case EventType.MouseDrag:
                    if (isResizingSplitter)
                    {
                        leftPaneWidth += Event.current.delta.x;
                        Repaint();
                        Event.current.Use();
                    }
                    break;
                case EventType.MouseUp:
                    if (isResizingSplitter)
                    {
                        isResizingSplitter = false;
                        Event.current.Use();
                    }
                    break;
            }
        }

        private void DrawRightPane()
        {
            float spacing = 100f;
            // Right pane container
            using (new EditorGUILayout.VerticalScope())
            {
                // 2/3 Inspector Section
                float inspectorHeight = (position.height - spacing) * 0.66f;
                rightScroll = EditorGUILayout.BeginScrollView(rightScroll, GUILayout.Height(inspectorHeight));

                if (inspectorHost != null && inspectorHost.IsValid)
                {
                    EditorGUILayout.Space(5f);
                    inspectorHost.DrawGUI();
                }
                else
                {
                    EditorGUILayout.Space(20f);
                    EditorGUILayout.HelpBox("Select materials in the hierarchy to begin.", MessageType.Info);
                }
                EditorGUILayout.EndScrollView();

                EditorGUILayout.Space(10f);

                // 1/3 Pending Changes Section
                float changesHeight = (position.height - spacing) * 0.33f;
                EditorGUILayout.LabelField("Pending Changes", EditorStyles.boldLabel);

                using (new EditorGUILayout.VerticalScope(EditorStyles.helpBox, GUILayout.Height(changesHeight)))
                {
                    DrawPendingChangesList();
                }
            }
        }

        private Vector2 changesScroll;

        private void DrawPendingChangesList()
        {
            changesScroll = EditorGUILayout.BeginScrollView(changesScroll);

            var changes = inspectorHost?.GetChangedSnapshots() ?? new List<SCSSPropertySnapshot>();

            if (changes.Count == 0)
            {
                EditorGUILayout.LabelField("No changes detected.", EditorStyles.centeredGreyMiniLabel);
            }
            else
            {
                foreach (var change in changes)
                {
                    // Sync our toggle mask
                    if (!applyMask.ContainsKey(change.Name)) applyMask[change.Name] = true;

                    using (new EditorGUILayout.HorizontalScope())
                    {
                        applyMask[change.Name] = EditorGUILayout.Toggle(applyMask[change.Name], GUILayout.Width(20));

                        string displayName = change.Name; // Or InspectorCommon.GetInspectorData(change.Name)
                        EditorGUILayout.LabelField(displayName);

                        // Show a mini-preview of the value
                        EditorGUILayout.LabelField(GetSnapshotValueString(change), EditorStyles.miniLabel, GUILayout.Width(100));
                    }
                }
            }
            EditorGUILayout.EndScrollView();
        }

        private string GetSnapshotValueString(SCSSPropertySnapshot s)
        {
            return s.Type switch
            {
                MaterialProperty.PropType.Float => s.FloatValue.ToString("F2"),
                MaterialProperty.PropType.Color => "Color",
                MaterialProperty.PropType.Texture => s.TextureValue?.name ?? "None",
                _ => "Changed"
            };
        }

        private void DrawStatusBar()
        {
            using (new EditorGUILayout.HorizontalScope(EditorStyles.helpBox))
            {
                var snapshots  = inspectorHost != null ? inspectorHost.GetSnapshotsToApply() : new List<SCSSPropertySnapshot>();
                var allChanges = inspectorHost != null ? inspectorHost.GetChangedSnapshots() : new List<SCSSPropertySnapshot>();
                var filteredChanges = allChanges.Where(c => applyMask.ContainsKey(c.Name) && applyMask[c.Name]).ToList();

                int selectedCount = 0;
                foreach (var entry in materialEntries) if (entry.IsSelected) selectedCount++;

                bool canApply = selectedCount > 0 && filteredChanges.Count > 0;

                using (new EditorGUI.DisabledScope(!canApply))
                {
                    if (GUILayout.Button("Apply To Selected Materials", GUILayout.Width(220f), GUILayout.Height(26f)))
                    {
                        SCSS_BulkEditorOperations.ApplyDirect(materialEntries, filteredChanges);
                        ShowNotification(new GUIContent($"Applied {filteredChanges.Count} properties to {selectedCount} materials."));
                    }

                    if (GUILayout.Button("Duplicate And Apply", GUILayout.Width(180f), GUILayout.Height(26f)))
                    {
                        SCSS_BulkEditorOperations.DuplicateAndApply(materialEntries, filteredChanges);
                        ShowNotification(new GUIContent($"Duplicated {selectedCount} materials and applied {filteredChanges.Count} properties."));
                        RequestAutoCollect(); // Refresh the left pane to show the new duplicated materials!
                    }
                }

                using (new EditorGUI.DisabledScope(!SCSS_BulkEditorOperations.CanRevert))
                {
                    if (GUILayout.Button("Revert Last Apply", GUILayout.Width(180f), GUILayout.Height(26f)))
                    {
                        SCSS_BulkEditorOperations.RevertLast();
                        ShowNotification(new GUIContent("Reverted previous operation."));
                        RequestAutoCollect();
                    }
                }

                GUILayout.FlexibleSpace();
                EditorGUILayout.LabelField($"Targets: {selectedCount}/{materialEntries.Count} | Props: {allChanges.Count}", EditorStyles.miniLabel);
            }
        }
    }
}
