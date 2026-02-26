#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>
using namespace metal;

[[ stitchable ]]
half4 Ripple(
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

    float adjustedTime = time - delay;
    float rippleAmount = amplitude * sin(frequency * adjustedTime) * exp(-decay * adjustedTime);

    rippleAmount *= smoothstep(0.0, 0.2, adjustedTime);

    float2 n = normalize(position - origin);
    float2 newPosition = position + rippleAmount * n;

    half4 color = layer.sample(newPosition);
    color.rgb += 0.3 * (half)rippleAmount;

    return color;
}
