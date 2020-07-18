

#ifndef SIGNEDDISTANCEFRACTALS_H
#define SIGNEDDISTANCEFRACTALS_H

#include "RaytracingShaderHelper.hlsli"
#include "SignedDistancePrimitives.hlsli"

//------------------------------------------------------------------


float4 quatSq(float4 q)
{
    float4 r;
    r.x = q.x * q.x - dot(q.yzw, q.yzw);
    r.yzw = 2 * q.x * q.yzw;
    return r;
}


float4 quatMult(float4 q1, float4 q2)
{
    float4 r;
    r.x = q1.x * q2.x - dot(q1.yzw, q2.yzw);
    r.yzw = q1.x * q2.yzw + q2.x * q1.yzw + cross(q1.yzw, q2.yzw);
    return r;
}

float sdGyroid(in float3 position) {
    return sin(position.x) * cos(position.y) + sin(position.y) * cos(position.x) + sin(position.z) * cos(position.x);
}
float sdQuaternionJuliaSet(in float3 position, float4 h, in float Scale = 2.0f) {
    float4 z = float4(position, 0.0);
    float4 c = float4(0.6, 0.6, 0.6, 0.6);
    float mag_z = dot(z, z);
    float4 z_prime = float4(1, 0, 0, 0);
    int Iterations = 15;
    float4 mag_dz = 1;
    for (int i = 0; i < Iterations; i++) {
        z = quatSq(z) + c;
        z_prime = 2 * quatMult(z, z_prime);
        mag_dz = dot(z_prime, z_prime);
        mag_z = dot(z, z);
        if (mag_z > 4) break;
    }

    return sqrt(mag_z) / (2 * sqrt(mag_dz)) * log(dot(z, z));
}
#endif // SIGNEDDISTANCEFRACTALS_H