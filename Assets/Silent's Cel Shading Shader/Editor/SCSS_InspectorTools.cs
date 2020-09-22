using UnityEditor;
using UnityEngine;
using System;
using UnityEngine.Rendering;
using Object = UnityEngine.Object;

// Parts of this file are based on https://github.com/Microsoft/MixedRealityToolkit-Unity/
// licensed under the MIT license. 

namespace SilentCelShading.Unity
{
	public class InspectorCommon
	{
		public enum OutlineMode
		{
			None,
			Tinted,
			Colored
		}

		public enum AlbedoAlphaMode
		{
			Transparency,
			Smoothness,
			ClippingMask
		}

		public enum SpecularType
		{
			Disable,
			Standard,
			Cloth,
			Anisotropic,
			Cel,
			CelStrand
		}

		public enum LightingCalculationType
		{
			Arktoon,
			Standard,
			Cubed,
			Directional
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
			AdditionalData = 2
		}

		public static class CommonStyles
		{
			public static string mainOptionsTitle = "Main Options";
			public static string renderingOptionsTitle = "Rendering Options";
			public static string shadingOptionsTitle = "Shading Options";
			public static string outlineOptionsTitle = "Outline Options";
			public static string advancedOptionsTitle = "Advanced Options";

			public static string albedoMapAlphaSmoothnessName = "_SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A";
			public static readonly string[] albedoAlphaModeNames = Enum.GetNames(typeof(AlbedoAlphaMode));
			
			public static GUIContent lightingCalculationType = new GUIContent("Lighting Calculation Type", "Sets the method used to perform the direct/indirect lighting calculation.");

			public static GUIContent mainTexture = new GUIContent("Main Texture", "Main Color Texture (RGBA)");
			public static GUIContent clippingMask = new GUIContent("Clipping Mask", "Additional texture for transparency.");
			public static GUIContent alphaCutoff = new GUIContent("Alpha Cutoff", "Threshold for transparency cutoff");
			public static GUIContent alphaSharp = new GUIContent("Disable Dithering", "Treats transparency cutoff as a hard edge, instead of a soft dithered one.");
			public static GUIContent colorMask = new GUIContent("Tint Mask", "Masks material colour tinting (G) and detail maps (A).");
			public static GUIContent normalMap = new GUIContent("Normal Map", "Normal Map (RGB)");

			public static GUIContent emissionMap = new GUIContent("Emission", "Emission (RGB)");
			public static GUIContent emissionDetailMask = new GUIContent("Emission Detail Mask", "A map combined with the main emission map to add detail.");
			public static GUIContent emissionDetailParams = new GUIContent("Emission Detail Parameters", "XY: Scroll pow");

			public static GUIContent specularMap = new GUIContent("Specular Map", "Specular Map (RGBA, RGB: Specular/Metalness, A: Smoothness)");
			public static GUIContent specularType = new GUIContent("Specular Style", "Allows you to set the shading used for specular. ");
			public static GUIContent smoothness = new GUIContent("Smoothness", "The smoothness of the material. The specular map's alpha channel is used for this, with this slider being a multiplier.");
			public static GUIContent anisotropy = new GUIContent("Anisotropy", "Direction of the anisotropic specular highlights.");
			public static GUIContent useEnergyConservation = new GUIContent("Use Energy Conservation", "Reduces the intensity of the diffuse on specular areas, to realistically conserve energy.");
			public static GUIContent useMetallic = new GUIContent("Use as Metalness", "Metalness maps are greyscale maps that contain the metalness of a surface. This is different to specular maps, which are RGB (colour) maps that contain the specular parts of a surface.");
			public static GUIContent celSpecularSoftness = new GUIContent("Softness", "Sets the softness of the falloff of cel specular highlights.");
			public static GUIContent celSpecularSteps = new GUIContent("Steps", "Sets the number of steps in cel specular highlights.");

			public static GUIContent useFresnel = new GUIContent("Rim Lighting Style", "Applies a customisable rim lighting effect.");
			public static GUIContent fresnelWidth = new GUIContent("Rim Width", "Sets the width of the rim lighting.");
			public static GUIContent fresnelStrength = new GUIContent("Rim Softness", "Sets the sharpness of the rim edge. ");
			public static GUIContent fresnelTint = new GUIContent("Rim Tint", "Tints the colours of the rim lighting. To make it brighter, change the brightness to a valur higher than 1.");

			public static GUIContent useFresnelLightMask = new GUIContent("Use Light Direction Mask", "Uses the light direction to split the rim light into two. The backside of the rim light can be adjusted seperately.");
			public static GUIContent fresnelLightMask = new GUIContent("Light Direction Mask Strength");
			public static GUIContent fresnelTintInv = new GUIContent("Inverse Rim Tint", "Tints the colours of the inverse rim lighting. To make it brighter, change the brightness to a valur higher than 1.");
			public static GUIContent fresnelWidthInv = new GUIContent("Inverse Rim Width", "Sets the width of the inverse rim lighting.");
			public static GUIContent fresnelStrengthInv = new GUIContent("Inverse Rim Softness", "Sets the sharpness of the inverse rim edge. ");

			public static GUIContent customFresnelColor = new GUIContent("Emissive Rim", "RGB sets the colour of the additive rim light. Alpha controls the power/width of the effect.");

			public static GUIContent outlineColor = new GUIContent("Outline Colour", "Sets the colour used for outlines. In tint mode, this is multiplied against the texture.");
			public static GUIContent outlineWidth = new GUIContent("Outline Width", "Sets the width of outlines in cm.");
			public static GUIContent outlineMask = new GUIContent("Outline Mask", "Sets the width of outlines.");

			public static GUIContent useMatcap = new GUIContent("Use Matcap", "Enables the use of material capture textures.");
			public static GUIContent matcapTitle = new GUIContent("Matcap", "Enables the use of material capture textures.");
			public static GUIContent matcap1Tex = new GUIContent("Matcap 1", "Matcap (RGB). Controlled by the matcap mask's R channel.");
			public static GUIContent matcap2Tex = new GUIContent("Matcap 2", "Matcap (RGB). Controlled by the matcap mask's G channel.");
			public static GUIContent matcap3Tex = new GUIContent("Matcap 3", "Matcap (RGB). Controlled by the matcap mask's B channel.");
			public static GUIContent matcap4Tex = new GUIContent("Matcap 4", "Matcap (RGB). Controlled by the matcap mask's A channel.");
			public static GUIContent matcapStrength = new GUIContent("Matcap Strength", "Power of the matcap. Higher is stronger.");
			public static GUIContent matcapMask = new GUIContent("Matcap Mask", "Determines the strength of the matcaps by the intensity of the different colour channels.");

			public static GUIContent useSubsurfaceScattering = new GUIContent("Use Subsurface Scattering", "Enables a light scattering effect useful for cloth and skin.");
			public static GUIContent thicknessMap = new GUIContent("Thickness Map", "Thickness Map (RGB)");
			public static GUIContent thicknessMapPower = new GUIContent("Thickness Map Power", "Boosts the intensity of the thickness map.");
			public static GUIContent thicknessInvert = new GUIContent("Invert Thickness", "Inverts the map used for thickness from a scale where 1 produces an effect, to a scale where 0 produces an effect.");
			public static GUIContent scatteringColor = new GUIContent("Scattering Color", "The colour used for the subsurface scattering effect.");
			public static GUIContent scatteringIntensity = new GUIContent("Scattering Intensity", "Strength of the subsurface scattering effect.");
			public static GUIContent scatteringPower = new GUIContent("Scattering Power", "Controls the power of the scattering effect.");
			public static GUIContent scatteringDistortion = new GUIContent("Scattering Distortion", "Controls the level of distortion light receives when passing through the material.");
			public static GUIContent scatteringAmbient = new GUIContent("Scattering Ambient", "Controls the intensity of ambient light received from scattering.");

			public static GUIContent lightSkew = new GUIContent("Light Skew", "Skews the direction of the received lighting. The default is (1, 0.1, 1, 0), which corresponds to normal strength on the X and Z axis, while reducing the effect of the Y axis. This essentially stops you from getting those harsh lights from above or below that look so weird on cel shaded models. But that's just a default...");
			public static GUIContent pixelSampleMode = new GUIContent("Pixel Art Mode", "Treats the main texture as pixel art. Great for retro avatars! Note: When using this, you should make sure mipmaps are Enabled and texture sampling is set to Trilinear.");

			public static GUIContent useDetailMaps = new GUIContent("Use Detail Maps", "Applies detail maps over the top of other textures for a more detailed appearance.");
			public static GUIContent detailAlbedoMap = new GUIContent("Detail Albedo x2", "An albedo map multiplied over the main albedo map to provide extra detail.");
			public static GUIContent detailNormalMap = new GUIContent("Detail Normal", "A normal map combined with the main normal map to add extra detail.");
			public static GUIContent specularDetailMask = new GUIContent("Specular Detail Mask", "The detail pattern to use over the specular map.");
			public static GUIContent uvSet = new GUIContent("Secondary UV Source", "Selects which UV channel to use for detail maps.");

			public static GUIContent highlights = new GUIContent("Specular Highlights", "Toggles specular highlights. Only applicable if specular is active.");
			public static GUIContent reflections = new GUIContent("Reflections", "Toggles glossy reflections. Only applicable if specular is active.");

			public static GUIContent diffuseGeomShadowFactor = new GUIContent("Diffuse Geometric Shadowing Factor","Controls the power of the geometric shadowing function, which alters the falloff of diffuse light at glancing angles. It's more realistic, but that can be undesirable for cel shading.");

			public static GUIContent lightWrappingCompensationFactor = new GUIContent("Light Reduction","Compensation factor for the light wrapping inherent in cel shading. For cel shaded models, this should be around 0.75. Realistic lighting should set this to 1 to disable it. ");

			public static GUIContent indirectShadingType = new GUIContent("Indirect Shading Type","Sets the method used to shade indirect lighting. Directional will pick a single direction as a fake light source, so light will always be sharp. Dynamic will use the overall shading as a base, allowing for blobbier and more accurate lighting. ");

			public static GUIContent useAnimation = new GUIContent("Use Animation", "Enables the spritesheet system, where textures provided to the shader are divided into sections and displayed seperately over time.");
			public static GUIContent animationSpeed = new GUIContent("Animation Speed", "The animation speed is derived from the Unity time parameter, where 1.0 is one cycle every 20 seconds. ");
			public static GUIContent animationTotalFrames = new GUIContent("Total Frames", "The maximum number of frames that will play in the animation. ");
			public static GUIContent animationFrameNumber = new GUIContent("Frame Number", "Sets the frame number to begin playing the animation on.");
			public static GUIContent animationColumns = new GUIContent("Columns", "Sets the number of frames present in a horizontal row.");
			public static GUIContent animationRows = new GUIContent("Rows", "Sets the number of frames present in a vertical column.");

			public static GUIContent useVanishing =  new GUIContent("Use Vanishing", "Enables the vanishing effect, which fades the material out at a set start and end point. Ineffective in opaque blend mode.");
			public static GUIContent vanishingStart =  new GUIContent("Start Vanishing", "The inner bound of the vanishing effect. The higher this is, the further out the material will finishing vanishing. If Start is higher than End, the material will be invisible at a distance.");
			public static GUIContent vanishingEnd =  new GUIContent("End Vanishing", "The outer bound of the vanishing effect. The higher this is, the further out the material will begin to vanish. If End is higher than Start, the material will be invisible up close.");

			public static GUIContent manualButton = new GUIContent("This shader has a manual. Check it out!","For information on new features, old features, and just how to use the shader in general, check out the manual on the shader wiki!");
		}

		public static void SetupMaterialWithAlbedo(Material material, MaterialProperty albedoMap, MaterialProperty albedoAlphaMode)
		{
			switch ((AlbedoAlphaMode)albedoAlphaMode.floatValue)
			{
				case AlbedoAlphaMode.Transparency:
				{
					material.DisableKeyword(CommonStyles.albedoMapAlphaSmoothnessName);
				}
				break;

				case AlbedoAlphaMode.Smoothness:
				{
					material.EnableKeyword(CommonStyles.albedoMapAlphaSmoothnessName);
				}
				break;
			}
		}

		public static void SetupMaterialWithOutlineMode(Material material, OutlineMode outlineMode)
		{
			string[] oldShaderName = material.shader.name.Split('/');
            const string outlineName = " (Outline)"; //
            var currentlyOutline = oldShaderName[oldShaderName.Length - 1].Contains(outlineName);
            switch ((OutlineMode)outlineMode)
            {
            	case OutlineMode.None:
            	if (currentlyOutline) {
            		string[] newShaderName = oldShaderName;
            		string newSubShader = oldShaderName[oldShaderName.Length - 1].Replace(outlineName, "");
            		newShaderName[oldShaderName.Length - 1] = newSubShader;
            		Shader finalShader = Shader.Find(String.Join("/", newShaderName));
                    // If we can't find it, pass.
            		if (finalShader != null) {
            			material.shader = finalShader;
            		}
            	}
            	break;
            	case OutlineMode.Tinted:
            	case OutlineMode.Colored:
            	if (!currentlyOutline) {
            		string[] newShaderName = oldShaderName;
            		string newSubShader = oldShaderName[oldShaderName.Length - 1] + outlineName;
            		newShaderName[oldShaderName.Length - 1] = newSubShader;
            		Shader finalShader = Shader.Find(String.Join("/", newShaderName));
                    // If we can't find it, pass.
            		if (finalShader != null) {
            			material.shader = finalShader;
            		}
            	}
            	break;
            }
        }

        public static void SetupMaterialWithSpecularType(Material material, SpecularType specularType)
        {
            // Note: _METALLICGLOSSMAP is used to avoid keyword problems with VRchat.
            // It's only a coincidence that the metallic map needs to be present.
            // Note: _SPECGLOSSMAP is used to switch to a version that doesn't sample
            // reflection probes. 
        	switch ((SpecularType)material.GetFloat("_SpecularType"))
        	{
        		case SpecularType.Standard:
        		material.SetFloat("_SpecularType", 1);
        		material.EnableKeyword("_METALLICGLOSSMAP");
        		material.DisableKeyword("_SPECGLOSSMAP");
        		break;
        		case SpecularType.Cloth:
        		material.SetFloat("_SpecularType", 2);
        		material.EnableKeyword("_METALLICGLOSSMAP");
        		material.DisableKeyword("_SPECGLOSSMAP");
        		break;
        		case SpecularType.Anisotropic:
        		material.SetFloat("_SpecularType", 3);
        		material.EnableKeyword("_METALLICGLOSSMAP");
        		material.DisableKeyword("_SPECGLOSSMAP");
        		break;
        		case SpecularType.Cel:
        		material.SetFloat("_SpecularType", 4);
        		material.EnableKeyword("_SPECGLOSSMAP");
        		material.DisableKeyword("_METALLICGLOSSMAP");
        		break;
        		case SpecularType.CelStrand:
        		material.SetFloat("_SpecularType", 5);
        		material.EnableKeyword("_SPECGLOSSMAP");
        		material.DisableKeyword("_METALLICGLOSSMAP");
        		break;
        		case SpecularType.Disable:
        		material.SetFloat("_SpecularType", 0);
        		material.DisableKeyword("_METALLICGLOSSMAP");
        		material.DisableKeyword("_SPECGLOSSMAP");
        		break;
        		default:
        		break;
        	}
        }

        public static void SetupMaterialWithVertexColorType(Material material, VertexColorType vertexColorType)
        {
        	switch ((VertexColorType)material.GetFloat("_VertexColorType"))
        	{
        		case VertexColorType.Color:
        		material.SetFloat("_VertexColorType", 0);
        		break;
        		case VertexColorType.OutlineColor:
        		material.SetFloat("_VertexColorType", 1);
        		break;
        		case VertexColorType.AdditionalData:
        		material.SetFloat("_VertexColorType", 2);
        		break;
        		default:
        		break;
        	}
        }
        
        public static void SetupMaterialWithLightingCalculationType(Material material, LightingCalculationType LightingCalculationType)
        {
        	switch ((LightingCalculationType)material.GetFloat("_LightingCalculationType"))
        	{   
        		case LightingCalculationType.Standard:
        		material.SetFloat("_LightingCalculationType", 1);
        		break;
        		case LightingCalculationType.Cubed:
        		material.SetFloat("_LightingCalculationType", 2);
        		break;
        		case LightingCalculationType.Directional:
        		material.SetFloat("_LightingCalculationType", 3);
        		break;
        		default:
        		case LightingCalculationType.Arktoon:
        		material.SetFloat("_LightingCalculationType", 0);
        		break;
        	}
        }

	    public static void UpgradeVariantCheck(Material material)
	    {
	        const string oldNoOutlineName = "☓ No Outline";
	        string newShaderName = "Silent's Cel Shading/Lightramp";
	        const string upgradeNotice = 
	        "Note: Updated the shader for material {0} to the new format.";
	        string[] currentShaderName = material.shader.name.Split('/');
	        // If they're the No Outline variant, it'll be in the path
	        var currentlyNoOutline = currentShaderName[currentShaderName.Length - 2].Equals(oldNoOutlineName);
	        newShaderName = currentlyNoOutline
	        ? newShaderName
	        : newShaderName + " (Outline)";
	        // Old shaders start with "Hidden/Silent's Cel Shading Shader/Old/"
	        if (currentShaderName[0] == "Hidden" && currentShaderName[2] == "Old")
	        {
	            // SetupMaterialWithRenderingMode
	            Shader finalShader = Shader.Find(newShaderName);
	            // If we can't find it, pass.
	            if (finalShader != null) {
	                material.shader = finalShader;
	                Debug.Log(String.Format(upgradeNotice, material.name, material.shader.name, newShaderName));
	            }
	        }
	    }
    }
}