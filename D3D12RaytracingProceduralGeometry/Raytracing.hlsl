//*********************************************************
//
// Copyright (c) Microsoft. All rights reserved.
// This code is licensed under the MIT License (MIT).
// THIS CODE IS PROVIDED *AS IS* WITHOUT WARRANTY OF
// ANY KIND, EITHER EXPRESS OR IMPLIED, INCLUDING ANY
// IMPLIED WARRANTIES OF FITNESS FOR A PARTICULAR
// PURPOSE, MERCHANTABILITY, OR NON-INFRINGEMENT.
//
//*********************************************************

#ifndef RAYTRACING_HLSL
#define RAYTRACING_HLSL

#define HLSL
#include "RaytracingHlslCompat.h"
#include "ProceduralPrimitivesLibrary.hlsli"
#include "RaytracingShaderHelper.hlsli"

//***************************************************************************
//*****------ Shader resources bound via root signatures -------*************
//***************************************************************************

// Scene wide resources.
//  g_* - bound via a global root signature.
//  l_* - bound via a local root signature.
RaytracingAccelerationStructure g_scene : register(t0, space0);
RWTexture2D<float4> g_renderTarget : register(u0);
ConstantBuffer<SceneConstantBuffer> g_sceneCB : register(b0);

// Triangle resources
ByteAddressBuffer g_indices : register(t1, space0);
StructuredBuffer<Vertex> g_vertices : register(t2, space0);

// Procedural geometry resources
StructuredBuffer<PrimitiveInstancePerFrameBuffer> g_AABBPrimitiveAttributes : register(t3, space0);
ConstantBuffer<PrimitiveConstantBuffer> l_materialCB : register(b1);
ConstantBuffer<PrimitiveInstanceConstantBuffer> l_aabbCB: register(b2);


//***************************************************************************
//****************------ Utility functions -------***************************
//***************************************************************************


//***************************************************************************
//*****------ TraceRay wrappers for radiance and shadow rays. -------********
//***************************************************************************

float FresnelAmount(float n1, float n2, float3 normal, float3 incident) {
    float r0 = (n1 - n2) / (n1 + n2);
    r0 *= r0;
    float cosx = -dot(normal, incident);
    if (n1 > n2) {
        float n = n1 / n2;
        float sint = n * n*(1.0f - cosx * cosx);

        if (sint > 1.0) {
            return 1.0;
        }
        cosx = sqrt(1.0 - sint);
    }
    float x = 1.0 - cosx;
    float ret = r0 + (1.0f - r0) * x * x * x * x * x;
    ret = (l_materialCB.reflectanceCoef + (1.0 - l_materialCB.reflectanceCoef) * ret);
    return ret;
}
float PhongLighting(float3 normal, bool shadowHit) {
    float3 position = HitWorldPosition();
    float3 lightDir = normalize(g_sceneCB.lightPosition.xyz - position);
    float3 viewDir = normalize(-WorldRayDirection());
    float3 refl = normalize(reflect(normal, lightDir));
    float illum;
    if (l_materialCB.refractiveCoef == 0) {
         illum = l_materialCB.diffuseCoef * saturate(dot(lightDir, normal));

        illum += l_materialCB.specularCoef * pow(saturate(dot(refl,viewDir)), l_materialCB.specularPower);
    }
    else {
        illum = l_materialCB.specularCoef * pow(saturate(dot(refl, viewDir)), l_materialCB.specularPower);

    }
    if (!shadowHit) {

    }
    else {
      //illum = 0;

    }
    return illum;
}

bool refractTest(float3 v, float3 normal, float index, inout float3 refracted) {
    float dt = dot(v, normal);
    float discriminant = 1.0 - index * index * (1 - dt * dt);
    if (discriminant > 0) {
        refracted = index * (v - normal * dt) - normal * sqrt(discriminant);
        return true;
    }
    else {
        return false;
    }
}
// Trace a radiance ray into the scene and returns a shaded color.
float4 TraceRadianceRay(in Ray ray, in UINT currentRayRecursionDepth)
{
    if (currentRayRecursionDepth >= MAX_RAY_RECURSION_DEPTH)
    {
        return float4(1,1,1, 1);
    }

    // Set the ray's extents.
    RayDesc rayDesc;
    rayDesc.Origin = ray.origin;
    rayDesc.Direction = ray.direction;
    // Set TMin to a zero value to avoid aliasing artifacts along contact areas.
    // Note: make sure to enable face culling so as to avoid surface face fighting.
    rayDesc.TMin = 0.0001;
    rayDesc.TMax = 10000;
    RayPayload rayPayload = { float4(0, 0, 0, 0), currentRayRecursionDepth + 1 };
    TraceRay(g_scene, RAY_FLAG_CULL_BACK_FACING_TRIANGLES,
        TraceRayParameters::InstanceMask,
        TraceRayParameters::HitGroup::Offset[RayType::Radiance],
        TraceRayParameters::HitGroup::GeometryStride,
        TraceRayParameters::MissShader::Offset[RayType::Radiance],
        rayDesc, rayPayload);

    return rayPayload.color;
}

float4 TraceRefractiveRay(in Ray ray, in RayPayload pay)
{
    if (pay.recursionDepth >= MAX_RAY_RECURSION_DEPTH)
    {
        return pay.color;
    }

    // Set the ray's extents.
    RayDesc rayDesc;
    rayDesc.Origin = ray.origin;
    rayDesc.Direction = ray.direction;
    // Set TMin to a zero value to avoid aliasing artifacts along contact areas.
    // Note: make sure to enable face culling so as to avoid surface face fighting.
    rayDesc.TMin = 0.0001f;
    rayDesc.TMax = 10000;
  //  RayPayload rayPayload = { float4(0, 0, 0, 0), currentRayRecursionDepth + 1 };
    pay.recursionDepth += 1;
    TraceRay(g_scene, RAY_FLAG_NONE,
        TraceRayParameters::InstanceMask,
        TraceRayParameters::HitGroup::Offset[RayType::Radiance],
        TraceRayParameters::HitGroup::GeometryStride,
        TraceRayParameters::MissShader::Offset[RayType::Radiance],
        rayDesc, pay);

    return pay.color;
}



bool ShadowRay(in Ray ray, in UINT currentRayRecursionDepth) {

    if (currentRayRecursionDepth >= MAX_RAY_RECURSION_DEPTH)
    {
        return false;
    }


    RayDesc rayDesc;
    rayDesc.Origin = ray.origin;
    rayDesc.Direction = ray.direction;
    rayDesc.TMin = 0;
    rayDesc.TMax = 10000;

    ShadowRayPayload shadow = { true };

    TraceRay(g_scene,
        RAY_FLAG_CULL_BACK_FACING_TRIANGLES
                   // ~skip any hit shaders
        | RAY_FLAG_SKIP_CLOSEST_HIT_SHADER, // ~skip closest hit shaders,  
        TraceRayParameters::InstanceMask,
        TraceRayParameters::HitGroup::Offset[RayType::Shadow],
        TraceRayParameters::HitGroup::GeometryStride,
        TraceRayParameters::MissShader::Offset[RayType::Shadow],
        rayDesc, shadow);

    return shadow.hit;
}


//***************************************************************************
//********************------ Ray gen shader.. -------************************
//***************************************************************************

[shader("raygeneration")]
void MyRaygenShader()
{
    // Generate a ray for a camera pixel corresponding to an index from the dispatched 2D grid.
    Ray ray = GenerateCameraRay(DispatchRaysIndex().xy, g_sceneCB.cameraPosition.xyz, g_sceneCB.projectionToWorld);
 
    // Cast a ray into the scene and retrieve a shaded color.
    UINT currentRecursionDepth = 0;
    float4 color = TraceRadianceRay(ray, currentRecursionDepth);

    // Write the raytraced color to the output texture.
    g_renderTarget[DispatchRaysIndex().xy] = color;
}

//***************************************************************************
//******************------ Closest hit shaders -------***********************
//***************************************************************************

[shader("closesthit")]
void MyClosestHitShader_Triangle(inout RayPayload rayPayload, in BuiltInTriangleIntersectionAttributes attr)
{
    uint indexSizeInBytes = 2;
    uint indicesPerTriangle = 3;
    uint triangleIndexStride = indicesPerTriangle * indexSizeInBytes;
    uint baseIndex = PrimitiveIndex() * triangleIndexStride;

    // Load up three 16 bit indices for the triangle.
    const uint3 indices = Load3x16BitIndices(baseIndex, g_indices);

    // Retrieve corresponding vertex normals for the triangle vertices.
    float3 triangleNormal = g_vertices[indices[0]].normal;
    float4 ambient = float4(0.1, 0.1, 0.1, 1);
    float3 hitPos = HitWorldPosition();
    float3 pos = HitWorldPosition();
    float3 dir = normalize(g_sceneCB.lightPosition.xyz - pos);
    Ray shadowRay;
    shadowRay.origin = HitWorldPosition();
    shadowRay.direction = dir;
    bool shadowHit = ShadowRay(shadowRay, rayPayload.recursionDepth);
    
    float4 reflectionColour = float4(0, 0, 0, 0);

    //float distance = length(g_sceneCB.lightPosition - HitWorldPosition());
    ambient += PhongLighting(float4(triangleNormal, 0), shadowHit);
    float n1 = 1;
    float n2 = 1.5;
    float index;
    float3 refracted;
    float3 dire = WorldRayDirection();
    float3 outwardNormal;
    if (dot(dir, triangleNormal) > 0) {
        outwardNormal = -triangleNormal;
        index = n2;
    }
    else {
        outwardNormal = triangleNormal;
        index = n1 / n2;
    }
    float4 refractionColour = float4(0, 0, 0, 1);
    if (refractTest(dire, outwardNormal, index, refracted)) {
        Ray r = { pos, refracted };
        //refraction is nosiy, huh?
       // refractionColour = float4(refracted, 1.0);
        refractionColour = TraceRefractiveRay(r, rayPayload);
    }
    else {
        Ray r = { pos, reflect(dir, triangleNormal) };
        refractionColour = TraceRadianceRay(r, rayPayload.recursionDepth);
    }
    rayPayload.color =  ambient + reflectionColour;

}


[shader("closesthit")]
void MyClosestHitShader_AABB(inout RayPayload rayPayload, in ProceduralPrimitiveAttributes attr)
{   


      
    // Shadow component.
    // Trace a shadow ray.
    
    float3 pos = HitWorldPosition();
    float3 l_dir = normalize(g_sceneCB.lightPosition.xyz - pos);
    Ray shadowRay = { pos, l_dir };
    float3 currentDir =    RayTCurrent() * WorldRayDirection();
    currentDir += WorldRayOrigin();
    float4 ambient = l_materialCB.albedo;
    bool shadowHit = ShadowRay(shadowRay, rayPayload.recursionDepth);
    float4 reflectionColour = float4(0, 0, 0, 0);
        //float distance = length(g_sceneCB.lightPosition - HitWorldPosition());
     ambient += PhongLighting(float4(attr.normal, 0), shadowHit);
     float4 refractionColour = float4(0, 0, 0, 1);
     float3 dir = normalize(WorldRayDirection());

      
     if (l_materialCB.refractiveCoef > 0) {
         //assume refractive glass
         float n1 = 1;
         float n2 = l_materialCB.refractiveCoef;
         float3 outwardNormal;
         float index;
         float3 refracted;
         if (dot(dir, attr.normal) > 0) {
             outwardNormal = -attr.normal;
             index = n2;
         }
         else {
             outwardNormal = attr.normal;
             index = n1 / n2;
         }
         if (refractTest(dir, outwardNormal, index, refracted)) {
             Ray r = { pos, refracted };
             //refraction is nosiy, huh?
            // refractionColour = float4(refracted, 1.0);
             refractionColour = TraceRefractiveRay(r, rayPayload);
         }
         else {
             Ray r = { pos, reflect(dir, attr.normal) };
             // refractionColour = TraceRadianceRay(r, rayPayload.recursionDepth);
         }
         float reflectMulti = FresnelAmount(n1, n2, attr.normal, dir);

       
     }
     if (l_materialCB.reflectanceCoef >= 0.5f) {
         Ray r = { pos, reflect(dir, attr.normal) };
         reflectionColour = TraceRadianceRay(r, rayPayload.recursionDepth);
     }
    
    
      //0.1f is a good coefficient for reflectioncolour.
       // rayPayload.color += refractionColour + 0.1*reflectionColour;
   //  rayPayload.color = refractionColour;
     rayPayload.color = ambient + refractionColour;
          //0.1*reflectionColour;
     //rayPayload.color =  float4(HitWorldPosition(), 1);
}

//***************************************************************************
//**********************------ Miss shaders -------**************************
//***************************************************************************

[shader("miss")]
void MyMissShader(inout RayPayload rayPayload)
{
    float4 backgroundColor = float4(BackgroundColor);
    rayPayload.color = backgroundColor;
}  

[shader("miss")]
void MyMissShader_ShadowRay(inout ShadowRayPayload rayPayload)
{
    

    rayPayload.hit = false;
}


[shader("anyhit")]
void AnyHit_AnalyticPrimitive(inout RayPayload payload, in ProceduralPrimitiveAttributes attr) {
    //IgnoreHit();
    float3 pos = HitWorldPosition();
    if (l_materialCB.refractiveCoef > 0) {
        // payload.color = float4(1, 1, 0, 1);
        //IgnoreHit();
    }
   // payload.color = float4(1, 1, 0, 1);
}

[shader("anyhit")]
void AnyHit_Triangle(inout RayPayload payload, in ProceduralPrimitiveAttributes attr) {
    
   IgnoreHit();
}
//***************************************************************************
//*****************------ Intersection shaders-------************************
//***************************************************************************

// Get ray in AABB's local space.
Ray GetRayInAABBPrimitiveLocalSpace()
{
    PrimitiveInstancePerFrameBuffer attr = g_AABBPrimitiveAttributes[l_aabbCB.instanceIndex];

    // Retrieve a ray origin position and direction in bottom level AS space 
    // and transform them into the AABB primitive's local space.
    Ray ray;
    ray.origin = mul(float4(ObjectRayOrigin(), 1), attr.bottomLevelASToLocalSpace).xyz;
    ray.direction = mul(ObjectRayDirection(), (float3x3) attr.bottomLevelASToLocalSpace);
    return ray;
}

[shader("intersection")]
void MyIntersectionShader_AnalyticPrimitive()
{
    Ray localRay = GetRayInAABBPrimitiveLocalSpace();
    AnalyticPrimitive::Enum primitiveType = (AnalyticPrimitive::Enum) l_aabbCB.primitiveType;

    float thit;
    ProceduralPrimitiveAttributes attr;
    if (RayAnalyticGeometryIntersectionTest(localRay, primitiveType, thit, attr))
    {
        PrimitiveInstancePerFrameBuffer aabbAttribute = g_AABBPrimitiveAttributes[l_aabbCB.instanceIndex];
        attr.normal = mul(attr.normal, (float3x3) aabbAttribute.localSpaceToBottomLevelAS);
        attr.normal = normalize(mul((float3x3) ObjectToWorld3x4(), attr.normal));

        ReportHit(thit, /*hitKind*/ 0, attr);
    }
}

[shader("intersection")]
void MyIntersectionShader_VolumetricPrimitive()
{
    Ray localRay = GetRayInAABBPrimitiveLocalSpace();
    VolumetricPrimitive::Enum primitiveType = (VolumetricPrimitive::Enum) l_aabbCB.primitiveType;
    
    float thit;
    ProceduralPrimitiveAttributes attr;
  
}

[shader("intersection")]
void MyIntersectionShader_SignedDistancePrimitive()
{
    Ray localRay = GetRayInAABBPrimitiveLocalSpace();
    SignedDistancePrimitive::Enum primitiveType = (SignedDistancePrimitive::Enum) l_aabbCB.primitiveType;

    float thit;
    ProceduralPrimitiveAttributes attr;
 
}

#endif // RAYTRACING_HLSL