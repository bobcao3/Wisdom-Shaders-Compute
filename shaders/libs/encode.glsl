#ifndef _INCLUDE_ENCODE
#define _INCLUDE_ENCODE

vec3 normalDecode(vec2 encodedNormal) {
	encodedNormal = encodedNormal * float(4.0) - float(2.0);
	float f = dot(encodedNormal, encodedNormal);
	float g = sqrt(float(1.0) - f * float(0.25));
	return vec3(encodedNormal * g, float(1.0) - f * float(0.5));
}

vec2 normalEncode(vec3 n) {
	vec2 enc = vec2(vec2(n.xy) * inversesqrt(float(n.z) * float(8.0) + float(8.0 + 0.00001)) + float(0.5));
	return enc;
}

#endif