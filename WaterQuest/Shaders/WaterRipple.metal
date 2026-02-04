#include <metal_stdlib>
#include <SwiftUI/SwiftUI.h>
#include <SwiftUI/SwiftUI_Metal.h>
using namespace metal;

// MARK: - Ripple Layer Effect
// Applies a layer-based ripple to a SwiftUI view.
[[ stitchable ]] half4 Ripple(
    float2 position,
    SwiftUI::Layer layer,
    float2 origin,
    float time,
    float amplitude,
    float frequency,
    float decay,
    float speed
) {
    float distance = length(position - origin);
    float delay = distance / speed;
    time = max(0.0, time - delay);

    float rippleAmount = amplitude * sin(frequency * time) * exp(-decay * time);
    float2 direction = normalize(position - origin + float2(0.001, 0.001));
    float2 newPosition = position + rippleAmount * direction;

    half4 color = layer.sample(newPosition);
    color.rgb += 0.3 * (rippleAmount / max(0.0001, amplitude)) * color.a;
    return color;
}

// MARK: - Water Ripple Distortion Effect
// Creates a realistic water ripple distortion effect

[[ stitchable ]] float2 waterRipple(
    float2 position,
    float4 bounds,
    float time,
    float2 touchPoint,
    float intensity,
    float frequency,
    float speed
) {
    // Calculate center of the effect area
    float2 center = touchPoint;
    
    // Distance from current position to center
    float dist = distance(position, center);
    
    // Create ripple wave
    float ripple = sin(dist * frequency - time * speed) * intensity;
    
    // Decay based on distance from center
    float decay = 1.0 / (1.0 + dist * 0.02);
    ripple *= decay;
    
    // Calculate displacement direction
    float2 direction = normalize(position - center + 0.001);
    
    // Apply displacement
    float2 displacement = direction * ripple;
    
    return position + displacement;
}

// MARK: - Concentric Water Ripple Effect
// Creates expanding concentric ripples from center

[[ stitchable ]] float2 concentricRipple(
    float2 position,
    float4 bounds,
    float time,
    float amplitude,
    float wavelength,
    float speed
) {
    float2 center = float2(bounds.z / 2.0, bounds.w / 2.0);
    float dist = distance(position, center);
    
    // Multiple wave frequencies for more realistic water
    float wave1 = sin(dist / wavelength - time * speed) * amplitude;
    float wave2 = sin(dist / (wavelength * 0.7) - time * speed * 1.3) * amplitude * 0.5;
    float wave3 = sin(dist / (wavelength * 1.4) - time * speed * 0.7) * amplitude * 0.3;
    
    float totalWave = wave1 + wave2 + wave3;
    
    // Fade out at edges
    float maxDist = min(bounds.z, bounds.w) / 2.0;
    float edgeFade = smoothstep(maxDist, maxDist * 0.3, dist);
    totalWave *= edgeFade;
    
    float2 direction = normalize(position - center + 0.001);
    return position + direction * totalWave;
}

// MARK: - Water Surface Color Effect
// Adds caustic-like light patterns to simulate light through water

[[ stitchable ]] half4 waterCaustics(
    float2 position,
    half4 color,
    float4 bounds,
    float time,
    float intensity
) {
    float2 uv = position / float2(bounds.z, bounds.w);
    
    // Create multiple overlapping sine waves for caustic pattern
    float caustic1 = sin(uv.x * 20.0 + time * 2.0) * sin(uv.y * 20.0 + time * 1.5);
    float caustic2 = sin(uv.x * 15.0 - time * 1.8 + uv.y * 10.0) * sin(uv.y * 25.0 + time * 2.2);
    float caustic3 = sin((uv.x + uv.y) * 18.0 + time * 1.2);
    
    float caustics = (caustic1 + caustic2 + caustic3) / 3.0;
    caustics = caustics * 0.5 + 0.5; // Normalize to 0-1
    caustics = pow(caustics, 2.0); // Increase contrast
    
    // Apply as brightness variation
    float brightness = 1.0 + caustics * intensity;
    
    return half4(color.rgb * brightness, color.a);
}

// MARK: - Shimmer Effect
// Creates a flowing shimmer/gleam effect

[[ stitchable ]] half4 shimmer(
    float2 position,
    half4 color,
    float4 bounds,
    float time,
    float width,
    float intensity
) {
    float2 uv = position / float2(bounds.z, bounds.w);
    
    // Diagonal shimmer line moving across
    float shimmerPos = fract(time * 0.3);
    float shimmerLine = uv.x + uv.y * 0.5;
    
    float shimmerValue = 1.0 - abs(shimmerLine - shimmerPos) / width;
    shimmerValue = max(0.0, shimmerValue);
    shimmerValue = pow(shimmerValue, 2.0);
    
    // Add sparkle highlights
    float sparkle = sin(uv.x * 50.0 + time * 3.0) * sin(uv.y * 50.0 - time * 2.5);
    sparkle = max(0.0, sparkle);
    sparkle = pow(sparkle, 8.0) * intensity * 0.5;
    
    float totalShimmer = shimmerValue * intensity + sparkle;
    
    return half4(color.rgb + totalShimmer, color.a);
}

// MARK: - Liquid Glass Refraction
// Simulates light refraction through glass with liquid properties

[[ stitchable ]] float2 liquidGlassRefraction(
    float2 position,
    float4 bounds,
    float time,
    float refractionStrength
) {
    float2 center = float2(bounds.z / 2.0, bounds.w / 2.0);
    float2 uv = (position - center) / center;
    
    // Organic flowing distortion
    float flow1 = sin(uv.x * 3.0 + time * 0.8) * cos(uv.y * 2.5 + time * 0.6);
    float flow2 = sin(uv.y * 4.0 - time * 0.7) * cos(uv.x * 3.5 + time * 0.9);
    
    float2 distortion = float2(flow1, flow2) * refractionStrength;
    
    // Edge-based magnification for glass-like effect
    float edgeDist = length(uv);
    float magnification = 1.0 + (1.0 - smoothstep(0.0, 1.0, edgeDist)) * 0.1;
    
    float2 result = position + distortion;
    result = center + (result - center) * magnification;
    
    return result;
}

// MARK: - Pulse Glow Effect
// Creates a pulsing glow that responds to progress

[[ stitchable ]] half4 pulseGlow(
    float2 position,
    half4 color,
    float4 bounds,
    float time,
    float progress,
    half4 glowColor
) {
    float2 center = float2(bounds.z / 2.0, bounds.w / 2.0);
    float dist = distance(position, center);
    float maxDist = min(bounds.z, bounds.w) / 2.0;
    
    // Normalized distance
    float normDist = dist / maxDist;
    
    // Pulse based on progress
    float pulse = sin(time * 3.0) * 0.5 + 0.5;
    pulse *= progress;
    
    // Glow intensity based on distance from edge of progress ring
    float ringDist = abs(normDist - 0.7); // 0.7 is approximate ring position
    float glowIntensity = smoothstep(0.15, 0.0, ringDist) * pulse;
    
    // Mix colors
    half4 result = color + glowColor * glowIntensity;
    return result;
}

// MARK: - Fluid Wave Background
// Creates an organic flowing wave pattern for backgrounds

[[ stitchable ]] half4 fluidWaveBackground(
    float2 position,
    half4 color,
    float4 bounds,
    float time,
    half4 waveColor1,
    half4 waveColor2
) {
    float2 uv = position / float2(bounds.z, bounds.w);
    
    // Multiple overlapping waves
    float wave1 = sin(uv.x * 6.0 + time * 0.5 + uv.y * 2.0) * 0.5 + 0.5;
    float wave2 = sin(uv.x * 4.0 - time * 0.3 + uv.y * 3.0) * 0.5 + 0.5;
    float wave3 = sin((uv.x + uv.y) * 5.0 + time * 0.4) * 0.5 + 0.5;
    
    float combinedWave = (wave1 + wave2 + wave3) / 3.0;
    
    // Smooth gradient based on vertical position
    float verticalGradient = uv.y;
    combinedWave = mix(combinedWave, verticalGradient, 0.5);
    
    // Mix between two colors
    half4 waveResult = mix(waveColor1, waveColor2, combinedWave);
    
    // Blend with original color
    return mix(color, waveResult, 0.3h);
}
