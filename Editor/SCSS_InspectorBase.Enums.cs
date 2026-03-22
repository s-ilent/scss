namespace SilentCelShading.Unity
{
    public partial class SCSSShaderGUI
    {
        public enum DepthWrite
        {
            Off,
            On
        }

        public enum RenderingMode
        {
            Opaque = 0,
            Cutout = 1,
            Fade = 2,
            Transparent = 3,
            Additive = 4,
            Custom = 5
        }

        public enum CustomRenderingMode
        {
            Opaque = 0,
            Cutout = 1,
            Fade = 2,
            Premultiplied = 3
        }
    }
}
