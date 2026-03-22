using UnityEngine;

namespace SilentCelShading.Unity
{
    public partial class Inspector
    {
        public enum ShadowMaskType
        {
            Occlusion, Tone, Auto
        }

        public enum LightRampType
        {
            Horizontal, Vertical, None
        }

        public enum ToneSeparationType
        {
            Combined, Separate
        }

        public enum IndirectShadingType
        {
            Dynamic, Directional, Flatten
        }

        public enum TransparencyMode
        {
            Soft, Sharp
        }

        public enum SpecularMetallicMode
        {
            Specular, Metalness
        }

        public enum DetailMapType
        {
            Albedo = 0, Normal = 1, Specular = 2, Alpha = 3
        }

        public enum DetailBlendMode
        {
            Multiply2x = 0, Multiply = 1, Add = 2, AlphaBlend = 3, Screen = 4, Subtract = 5
        }

        public enum TintApplyMode
        {
            Tint = 0, HSV = 1
        }

        public enum UVLayers
        {
            UV0 = 0, UV1 = 1, UV2 = 2, UV3 = 3
        }

        public enum FurMode
        {
            None = 0, On = 1
        }

        public enum EmissionMode
        {
            Additive = 0, Mask = 1
        }

        public enum SDFMode
        {
            None = 0, SingleChannel = 1, DualChannel = 2
        }

        public enum CardinalDir
        {
            [InspectorName("+X")] PosX = 0, // +X
            [InspectorName("-X")] NegX = 1, // -X
            [InspectorName("+Y")] PosY = 2, // +Y
            [InspectorName("-Y")] NegY = 3, // -Y
            [InspectorName("+Z")] PosZ = 4, // +Z
            [InspectorName("-Z")] NegZ = 5  // -Z
        }

        public enum VertexColorChannelType
        {
            Ignore = 0,
            OutlineWidth = 1,
            Occlusion = 2,
            OutlineDepth = 3,
            RampID = 4,
            Alpha = 5,
            OutlineAlpha = 6
        }

        public enum OutlineCalculationMode
        {
            WorldSpace = 0,
            ClipSpace = 1
        }

        public enum SettingsComplexityMode
        {
            Complex, Normal, Simple
        }

        public enum MaterialType
        {
            Lightramp, Crosstone
        }

        public enum MaterialGeomType
        {
            None, Outline, Fur
        }
    }

    public partial class InspectorCommon
    {
        public enum OutlineMode
        {
            None,
            Tinted,
            Colored
        }

        public enum AlbedoAlphaMode
        {
            Transparency = 0,
            Smoothness = 1,
            ClippingMask = 2
        }

        public enum SpecularType
        {
            Disable = 0,
            Standard = 1,
            Cloth = 2,
            Anisotropic = 3,
            Cel = 4,
            CelStrand = 5,
            Glinty = 6
        }

        public enum LightingCalculationType
        {
            Unbiased = 0,
            Standard = 1,
            Cubed = 2,
            Directional = 3,
            Biased = 4
        }

        public enum AmbientFresnelType
        {
            Disable,
            Lit,
            Ambient,
            AmbientAlt
        }

        public enum MatcapBlendModes
        {
            Additive,
            Multiply,
            Median,
        }

        public enum MatcapType
        {
            Disable,
            Standard,
            Anisotropic
        }

        public enum VertexColorType
        {
            Color = 0,
            OutlineColor = 1,
            CustomData = 2,
            Ignore = 3,
            OutlineDirection = 4
        }

        public enum InspectorLanguageSelection
        {
            English, 日本語
        }
    }
}
