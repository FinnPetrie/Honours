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

//**********************************************************************************************
//
// AnalyticPrimitives.hlsli
//
// Set of ray vs analytic primitive intersection tests.
//
//**********************************************************************************************

#ifndef ANALYTICPRIMITIVES_H
#define ANALYTICPRIMITIVES_H


#include "RaytracingShaderHelper.hlsli"

// Solve a quadratic equation.
// Ref: https://www.scratchapixel.com/lessons/3d-basic-rendering/minimal-ray-tracer-rendering-simple-shapes/ray-sphere-intersection
bool SolveQuadraticEqn(float a, float b, float c, out float x0, out float x1)
{
    float discr = b * b - 4 * a * c;
    if (discr < 0) return false;
    else if (discr == 0) x0 = x1 = -0.5 * b / a;
    else {
        float q = (b > 0) ?
            -0.5 * (b + sqrt(discr)) :
            -0.5 * (b - sqrt(discr));
        x0 = q / a;
        x1 = c / q;
    }
    if (x0 > x1) swap(x0, x1);

    return true;
}

float3 CalculateNormalForARayQuadricHitCSG(in Ray r, in float thit, in float4x4 Q)
{
    float n_x, n_y, n_z;
    float3 intersectionPoint;
    float3 dir = normalize(r.direction);

    intersectionPoint = r.origin + thit * r.direction;

    float4 Q_X = mul(Q, float4(intersectionPoint, 1));
    n_x = dot(float4(2, 0, 0, 0), Q_X);
    n_y = dot(float4(0, 2, 0, 0), Q_X);
    n_z = dot(float4(0, 0, 2, 0), Q_X);
    float3 norm = normalize(float3(n_x, n_y, n_z));

  

    return norm;
}
// Calculate a normal for a hit point on a sphere.
float3 CalculateNormalForARaySphereHit(in Ray ray, in float thit, float3 center)
{
    float3 hitPosition = ray.origin + thit * ray.direction;
    return normalize(hitPosition - center);
}

float3 CalculateNormalForARayQuadricHit(in Ray r, in float thit, in float4x4 Q)
{
    float n_x, n_y, n_z;
    float3 intersectionPoint;
    float3 dir = normalize(r.direction);

    intersectionPoint = r.origin + thit * r.direction;

    float4 Q_X = mul(Q, float4(intersectionPoint, 1));
    n_x = dot(float4(2, 0, 0, 0), Q_X);
    n_y = dot(float4(0, 2, 0, 0), Q_X);
    n_z = dot(float4(0, 0, 2, 0), Q_X);
    float3 norm = normalize(float3(n_x, n_y, n_z));

    if (dot(norm, dir) > 0) {
        norm = -norm;
    }

    return norm;
}
// Analytic solution of an unbounded ray sphere intersection points.
// Ref: https://www.scratchapixel.com/lessons/3d-basic-rendering/minimal-ray-tracer-rendering-simple-shapes/ray-sphere-intersection
bool SolveRaySphereIntersectionEquation(in Ray ray, out float tmin, out float tmax, in float3 center, in float radius)
{
    float3 L = ray.origin - center;
    float a = dot(ray.direction, ray.direction);
    float b = 2 * dot(ray.direction, L);
    float c = dot(L, L) - radius * radius;

    return SolveQuadraticEqn(a, b, c, tmin, tmax);
}




bool SolveRayQuadricInteresection(in Ray ray, out float tmin, out float tmax, in float4x4 Q) {

    float4 AD = mul(Q, float4(ray.direction, 0));
    float4 AC = mul(Q, float4(ray.origin, 1));

    float a = dot(float4(ray.direction, 0), AD);
    float b = dot(float4(ray.origin, 1), AD) + dot(float4(ray.direction, 0), AC);
    float c = dot(float4(ray.origin, 1), AC);
    if (abs(a) == 0) {
        float t = -c / b;
        tmin = t;
        tmax = t;
        return true;
    }

    return SolveQuadraticEqn(a, b, c, tmin, tmax);
}


bool cornellBoxUnColoured(in Ray r, inout float tmin, inout float tmax, out float thit, out ProceduralPrimitiveAttributes attr) {
    //intersect ray with plane at 
    float eps = 0.001;
    //first normal 
    float3 n1 = float3(0, -1, 0);
    float3 n2 = float3(0, 1, 0);
    float3 n3 = float3(0, 0, 1);

    float d1 = dot(r.direction, n1);
    float d2 = dot(r.direction, n2);
    float d3 = dot(r.direction, n3);

    float3 p_1 = -(r.origin - float3(0, 2, 0));
    float3 p_2 = -(r.origin - float3(0, -2, 0));
    float3 p_3 = -(r.origin - float3(0, 0, -2));

    float t1 = dot(p_1, n1) / d1;
    float t2 = dot(p_2, n2) / d2;
    float t3 = dot(p_3, n3) / d3;
    
    float3 i1, i2, i3;

    bool inter1, inter2, inter3 = false;
    
    if (t1 > eps) {
        i1 = r.origin + t1 * r.direction;
        if ((abs(i1.x <= 2)) && abs((i1.z <= 2))) {
            inter1 = true;
        }
    }

    if (t2 > eps) {
        i2 = r.origin + t2 * r.direction;
        if ((abs(i2.x <= 2)) && (abs( i2.z <= 2))) {
            inter2 = true;
        }
    }

    if (t3 > eps) {
        i3 = r.origin + t3 * r.direction;
        if ((abs(i3.y <= 2)) && (abs(i3.x <= 2))) {
            inter3 = true;
        }
    }




    if (t1 < t2 && t1 < t3 && inter1) {
        attr.normal = n1;
        thit = t1;
        tmin = tmax = t1;
        return true;

    }
    else if (t2 < t1 && t2 < t3 && inter2) {
        attr.normal = n2;
        thit = t2;
        tmin = tmax = t2;
        return true;

    }
    else if (t3 < t2 && t3 < t1 && inter3) {
        attr.normal = n3;
        thit = t3;
        tmin = tmax = t3;
        return true;
    }
    return false;
    //figure out which hit point was closest
}

bool rayPlaneCSGHyp(in Ray r, inout float thit, out ProceduralPrimitiveAttributes attr, float3 normal, float radius, float translation, in float minimum) {
    float epsilon = 0.00001;

    //   float translation = 0;

    double z0 = translation - r.origin.x;
    double dz = r.direction.x;

    double t = z0 / dz;
    if (t < minimum) {
        return false;
    }
    if (abs(dz) < epsilon) {
        return false;
    }


    float3 intersectionPoint = r.origin + t * r.direction;

    if (abs(dot(intersectionPoint.yz, intersectionPoint.yz)) <= radius) {
        attr.normal = normal;

        thit = t;

        return true;
    }


    return false;
    //float t2 = 1 - r.origin.x / r.direction.x;

   /* float3 p_2 = -(r.origin - translation);
    float t1 = dot(p_2, normal) / denominator;
    float3 intersectionPoint;
    if (t1 > epsilon) {
        intersectionPoint = r.origin + t1 * r.direction;
        if ((abs(intersectionPoint.x < 1)) && (abs(intersectionPoint.y) < 1)) {
            if (sqrt(dot(intersectionPoint.xy, intersectionPoint.xy)) <= 1) {
                thit = t1;
                tmin = tmax = t1;
                attr.normal = normal;
                if (dot(attr.normal, r.direction) > 0) {
                    attr.normal = -attr.normal;
                }
                return true;
            }
        }


    }
    return false;*/
}



bool rayPlaneCSG(in Ray r, inout float thit, out ProceduralPrimitiveAttributes attr, float3 normal, float radius, float translation, in float minimum) {
    float epsilon = 0.00001;

    //   float translation = 0;

    double z0 = translation - r.origin.y;
    double dz = r.direction.y;

    double t = z0 / dz;
    if (t < minimum) {
        return false;
    }
    if (abs(dz) < epsilon) {
        return false;
    }


    float3 intersectionPoint = r.origin + t * r.direction;

        if (abs(dot(intersectionPoint.xz, intersectionPoint.xz)) <= radius) {
            attr.normal = normal;

            thit = t;
        
            return true;
        }
    

    return false;
    //float t2 = 1 - r.origin.x / r.direction.x;

   /* float3 p_2 = -(r.origin - translation);
    float t1 = dot(p_2, normal) / denominator;
    float3 intersectionPoint;
    if (t1 > epsilon) {
        intersectionPoint = r.origin + t1 * r.direction;
        if ((abs(intersectionPoint.x < 1)) && (abs(intersectionPoint.y) < 1)) {
            if (sqrt(dot(intersectionPoint.xy, intersectionPoint.xy)) <= 1) {
                thit = t1;
                tmin = tmax = t1;
                attr.normal = normal;
                if (dot(attr.normal, r.direction) > 0) {
                    attr.normal = -attr.normal;
                }
                return true;
            }
        }


    }
    return false;*/
}

bool rayPlaneCSGCone(in Ray r, inout float thit, out ProceduralPrimitiveAttributes attr, float3 normal, float radius, float3 translation, in float minimum) {
    float epsilon = 0.00001;

    //   float translation = 0;

    double z0 = translation + r.origin.y;
    double dz = r.direction.y;

    double t = -z0 / dz;
    if (t < minimum) {
        return false;
    }
    if (abs(dz) < epsilon) {
        return false;
    }


    float3 intersectionPoint = r.origin + t * r.direction;

    if ((abs(intersectionPoint.z <= 3)) && (abs(intersectionPoint.x) <= 3)) {
        if (abs(dot(intersectionPoint.xz, intersectionPoint.xz)) <= radius) {
            attr.normal = float3(0, 1, 0);

            thit = t;

            return true;
        }
    }

    return false;
    //float t2 = 1 - r.origin.x / r.direction.x;

   /* float3 p_2 = -(r.origin - translation);
    float t1 = dot(p_2, normal) / denominator;
    float3 intersectionPoint;
    if (t1 > epsilon) {
        intersectionPoint = r.origin + t1 * r.direction;
        if ((abs(intersectionPoint.x < 1)) && (abs(intersectionPoint.y) < 1)) {
            if (sqrt(dot(intersectionPoint.xy, intersectionPoint.xy)) <= 1) {
                thit = t1;
                tmin = tmax = t1;
                attr.normal = normal;
                if (dot(attr.normal, r.direction) > 0) {
                    attr.normal = -attr.normal;
                }
                return true;
            }
        }


    }
    return false;*/
}
bool rayPlane(in Ray r,  inout float thit, out ProceduralPrimitiveAttributes attr, float3 normal, float radius, float3 translation) {
    float epsilon = 0.00001;
    
 //   float translation = 0;
   
    double z0 = translation + r.origin.x;
    double dz = r.direction.x;

    double t =  -z0 / dz;

    if (abs(dz) < epsilon) {
        return false;
    }


    float3 intersectionPoint = r.origin + t * r.direction;
   
    if ((abs(intersectionPoint.z <= 3)) && (abs(intersectionPoint.y) <= 3)) {
        if (abs(dot(intersectionPoint.zy, intersectionPoint.zy)) <= radius) {
            attr.normal = float3(0, 0, 1);

            thit = t;
            if (dot(attr.normal, r.direction) > 0) {
               // attr.normal = -attr.normal;
            }
            return true;
        }
    }
    
    return false;
    //float t2 = 1 - r.origin.x / r.direction.x;
  
   /* float3 p_2 = -(r.origin - translation);
    float t1 = dot(p_2, normal) / denominator;
    float3 intersectionPoint;
    if (t1 > epsilon) {
        intersectionPoint = r.origin + t1 * r.direction;
        if ((abs(intersectionPoint.x < 1)) && (abs(intersectionPoint.y) < 1)) {
            if (sqrt(dot(intersectionPoint.xy, intersectionPoint.xy)) <= 1) {
                thit = t1;
                tmin = tmax = t1;
                attr.normal = normal;
                if (dot(attr.normal, r.direction) > 0) {
                    attr.normal = -attr.normal;
                }
                return true;
            }
        }
        

    }
    return false;*/
}
bool QuadricRayIntersectionTest(in Ray r, inout float tmin, inout float tmax, out float thit, out ProceduralPrimitiveAttributes attr, in AnalyticPrimitive::Enum analyticPrimitive = AnalyticPrimitive::Enum::Hyperboloid, in float4x4 Q = float4x4(-1.0f, 0.0f, 0.0f, 0.0f,
    0.0f, 1.0f, 0.0f, 0.0f,
    0.0f, 0.0f, 1.0f, 0.0f,
    0.0f, 0.0f, 0.0f, -1.0f)) {


    float n_x, n_y, n_z;
    bool plane = false;

 

    if (!SolveRayQuadricInteresection(r, tmin, tmax, Q)) {
        return false;
    }

    //determine whether qudraic or plane intersection is closer
    
    

    if (tmin < RayTMin()) {
        if (tmax < RayTMin()) {
            return false;
        }
        thit = tmax;
    }
    else {
        thit = tmin;
    }

   
    float3 intersectionPoint = r.origin + thit * r.direction;

    if (abs(intersectionPoint.x) > 2) {
        thit = tmax;
        tmin = tmax;
    }

    if (analyticPrimitive == AnalyticPrimitive::Paraboloid || analyticPrimitive == AnalyticPrimitive::Cone) {
        if ((abs(intersectionPoint.y) > 2) || (abs(intersectionPoint.z) > 2)) {
            thit = tmax;
            tmin = tmax;
        }
    }
    if (analyticPrimitive == AnalyticPrimitive::Cylinder) {
        if ((abs(intersectionPoint.y) > 0.5) || (abs(intersectionPoint.z) > 2)) {
            thit = tmax;
            tmin = tmax;
        }
    }
    intersectionPoint = r.origin + thit * r.direction;



    //bound along x-axis
    if (abs(intersectionPoint.x) > 2) {
        return false;
    }

    //bound y for cylinder
    if (analyticPrimitive == AnalyticPrimitive::Cylinder) {
        if ((abs(intersectionPoint.y) > 0.5) || (abs(intersectionPoint.z) > 2)) {
            return false;
        }
   }
    //todo -- add caps - intersect planes
    
    /*if(analyticPrimitive == AnalyticPrimitive::Cylinder) {
        if (intersectionPoint.x == 2) {
            attr.normal = float3(1, 0, 0);

        }
        else if (intersectionPoint.x == -2) {
            attr.normal = float3(-1, 0, 0);
        }
    }*/

    //bound paraboloid in all axes
    
    if (analyticPrimitive == AnalyticPrimitive::Cone) {
        if ((abs(intersectionPoint.y) > 2) || (abs(intersectionPoint.z) > 2)) {
            return false;
        }
    }  
    if (analyticPrimitive == AnalyticPrimitive::Paraboloid) {
        if ((abs(intersectionPoint.y) > 2) || (abs(intersectionPoint.x) > 2)) {
            return false;
        }
    }

    attr.normal = CalculateNormalForARayQuadricHit(r, thit, Q);

    tmin = thit;
    return true;
}

bool RayQuadric(in Ray ray, out float thit, out ProceduralPrimitiveAttributes attr, in AnalyticPrimitive::Enum type) {
 
    //thit = RayTCurrent();

    float4x4 Q;
    bool hitFound = false;
    switch (type) {
    case AnalyticPrimitive::Hyperboloid: Q = float4x4( -1.0f ,0.0f, 0.0f, 0.0f,
                                                    0.0f, 1.0f, 0.0f,  0.0f,
                                                     0.0f, 0.0f, 1.0f , 0.0f,
                                                       0.0f, 0.0f, 0.0f, -1.0f );
        break;
    case AnalyticPrimitive::Ellipsoid: Q = float4x4( 1.0f / 1.5f, 0.0f, 0.0f,0.0f,
                                             0.0f, 1.0f, 0.0f, 0.0f,
                                              0.0f, 0.0f, 1.0f / 2.0f , 0.0f,
                                              0.0f, 0.0f, 0.0f, -1.0f );
        break;
    case AnalyticPrimitive::Paraboloid: Q = float4x4 ( 1.0f / 2, 0.0f, 0.0f, 0.0f,
                                                0.0f, 0.0f, 0.0f,  -0.1f,
                                                 0.0f, 0.0f, 1.0f / 1.5f, 0.0f,
                                                   0.0f, -0.1f, 0.0f, 0.0f );
        break;
    case AnalyticPrimitive::Cylinder: Q = float4x4(1.0f, 0.0f, 0.0f, 0.0f,
                                        0.0f, 0.0f, 0.0f, 0.0f,
                                        0.0f, 0.0f, 1.0f, 0.0f,
                                        0.0f, 0.0f, 0.0f, -3.0f );
        break;
    case AnalyticPrimitive::Cone: Q = float4x4 (-1.0f, 0.0f, 0.0f, 0.0f,
                                                0.0f, 1.0f, 0.0f, 0.0f,
                                                0.0f, 0.0f, -1.0f, 0.0f,
                                                0.0f, 0.0f, 0.0f, 0.0f);
        break;
    case AnalyticPrimitive::Sphere: Q = float4x4(1.0f, 0.0f, 0.0f, 0.0f,
        0.0f, 1.0f, 0.0f, 0.0f,
        0.0f, 0.0f, 1.0f, 0.0f,
        0.0f, 0.0f, 0.0f, -1.0f);
        break;
    case AnalyticPrimitive::PointLightSphere: Q = float4x4(1.0f, 0.0f, 0.0f, 0.0f,
        0.0f, 1.0f, 0.0f, 0.0f,
        0.0f, 0.0f, 1.0f, 0.0f,
        0.0f, 0.0f, 0.0f, -0.2f);
     default: return false;

    }

    float _tmin;
    float _thit;
    float _tmax;
    ProceduralPrimitiveAttributes _attr;

    if (QuadricRayIntersectionTest(ray, _tmin, _tmax, _thit, _attr, type, Q))
    {
       
            thit = _thit;
            attr = _attr;
            hitFound = true;
        
    }

   /* float left_tmin, left_tmax, left_thit, right_tmin, right_tmax, right_thit;
    ProceduralPrimitiveAttributes leftPlane, rightPlane;
    if(type == AnalyticPrimitive::Cylinder) {
        //intersect ray with planes at (1, 0,0), and (-1, 0, 0)
       if (rayPlane(ray, left_tmin, left_tmax, left_thit, leftPlane, float3(1, 0, 0), 1, float3(-2, 0, 0))) {
            if ((_thit > left_thit) || (!hitFound)) {
                thit = left_thit;
                attr = leftPlane;
                hitFound = true;
            }
        }
       if (rayPlane(ray, right_tmin, right_tmax, right_thit, rightPlane, float3(1, 0, 0),  1, float3(2, 0, 0))) {
           if ((_thit > right_thit) || (!hitFound)) {
               thit = right_thit;
               attr = rightPlane;
               hitFound = true;
           }
       }
    }*/
 
    return hitFound;

}

/**
void insertSort(inout float4 a, int length)
{
    int i, j, value;
    for (i = 1; i < length; i++)
    {
        value = a[i];
        for (j = i - 1; j >= 0 && a[j] > value; j--)
            a[j + 1] = a[j];
        a[j + 1] = value;
    }
}*/


void insertionSort(inout float4 intersections) {

    int j;
    float key;
    for (int i = 1; i < 4; i++) {
        key = intersections[i];
        j = i - 1;
        while (j >= 0 && intersections[j] > key) {
            intersections[j + 1] = intersections[j];
            j--;
        }
        intersections[j + 1] = key;
    }
}



bool QuadricRayIntersectionTestCSG (in Ray r, in float minimum, inout float tmin, inout float tmax, out float thit, out ProceduralPrimitiveAttributes attr, in AnalyticPrimitive::Enum analyticPrimitive = AnalyticPrimitive::Enum::Hyperboloid, in float4x4 Q = float4x4(-1.0f, 0.0f, 0.0f, 0.0f,
    0.0f, 1.0f, 0.0f, 0.0f,
    0.0f, 0.0f, 1.0f, 0.0f,
    0.0f, 0.0f, 0.0f, -1.0f)) {


    float n_x, n_y, n_z;
    bool plane = false;



    if (!SolveRayQuadricInteresection(r, tmin, tmax, Q)) {
        return false;
    }

    //determine whether qudraic or plane intersection is closer



    if (tmin <minimum ) {
        if (tmax < minimum) {
            return false;
        }
        thit = tmax;
    }
    else {
        thit = tmin;
    }


    float3 intersectionPoint = r.origin + thit * r.direction;

    if (abs(intersectionPoint.x) > 2) {
        thit = tmax;
        tmin = tmax;
    }

    if (analyticPrimitive == AnalyticPrimitive::Paraboloid || analyticPrimitive == AnalyticPrimitive::Cone) {
        if ((abs(intersectionPoint.y) > 2) || (abs(intersectionPoint.z) > 2)) {
            thit = tmax;
            tmin = tmax;
        }
    }
    if (analyticPrimitive == AnalyticPrimitive::Cylinder) {
        if ((abs(intersectionPoint.y) > 0.5) || (abs(intersectionPoint.z) > 2)) {
            thit = tmax;
            tmin = tmax;
        }
    }

    if (analyticPrimitive == AnalyticPrimitive::BigCylinder) {
        if ((abs(intersectionPoint.y) > 1) || (abs(intersectionPoint.z) > 2)) {
            thit = tmax;
            tmin = tmax;
        }
    }
    if (analyticPrimitive == AnalyticPrimitive::SmallCylinder) {
        if (((intersectionPoint.y) > 1.5 )|| ((intersectionPoint.y) < -0.75) || (abs(intersectionPoint.z) > 2)) {
            return false;
        }
    }
    intersectionPoint = r.origin + thit * r.direction;



    //bound along x-axis
    if (abs(intersectionPoint.x) > 2) {
        return false;
    }

    //bound y for cylinder
    if (analyticPrimitive == AnalyticPrimitive::Cylinder) {
        if ((abs(intersectionPoint.y) > 0.5) || (abs(intersectionPoint.z) > 2)) {
            return false;
        }
    }
    if (analyticPrimitive == AnalyticPrimitive::BigCylinder) {
        if ((abs(intersectionPoint.y) > 1) || (abs(intersectionPoint.z) > 2)) {
            return false;
        }
    }
    if (analyticPrimitive == AnalyticPrimitive::SmallCylinder) {
        if (((intersectionPoint.y) > 1.5) || ((intersectionPoint.y) < -0.75) || (abs(intersectionPoint.z) > 2)) {
            return false;
        }
    }
    //todo -- add caps - intersect planes

    /*if(analyticPrimitive == AnalyticPrimitive::Cylinder) {
        if (intersectionPoint.x == 2) {
            attr.normal = float3(1, 0, 0);

        }
        else if (intersectionPoint.x == -2) {
            attr.normal = float3(-1, 0, 0);
        }
    }*/

    //bound paraboloid in all axes

    if (analyticPrimitive == AnalyticPrimitive::Cone) {
        if ((abs(intersectionPoint.y) > 2) || (abs(intersectionPoint.z) > 2)) {
            return false;
        }
    }
    if (analyticPrimitive == AnalyticPrimitive::Paraboloid) {
        if ((abs(intersectionPoint.y) > 2) || (abs(intersectionPoint.x) > 2)) {
            return false;
        }
    }

    attr.normal = CalculateNormalForARayQuadricHitCSG(r, thit, Q);

    tmin = thit;
    return true;
}

bool OtherCSGRayTest(in Ray ray, in float minimum, out float thit, out float3 normal, in AnalyticPrimitive::Enum type) {

    //thit = RayTCurrent();

    float4x4 Q;
    bool hitFound = false;
    switch (type) {
    case AnalyticPrimitive::Hyperboloid: Q = float4x4(-1.0f, 0.0f, 0.0f, 0.0f,
        0.0f, 1.0f, 0.0f, 0.0f,
        0.0f, 0.0f, 1.0f, 0.0f,
        0.0f, 0.0f, 0.0f, -1.0f);
        break;
    case AnalyticPrimitive::Ellipsoid: Q = float4x4(1.0f / 1.5f, 0.0f, 0.0f, 0.0f,
        0.0f, 1.0f, 0.0f, 0.0f,
        0.0f, 0.0f, 1.0f / 2.0f, 0.0f,
        0.0f, 0.0f, 0.0f, -1.0f);
        break;
    case AnalyticPrimitive::Paraboloid: Q = float4x4 (1.0f / 2, 0.0f, 0.0f, 0.0f,
        0.0f, 0.0f, 0.0f, -0.1f,
        0.0f, 0.0f, 1.0f / 1.5f, 0.0f,
        0.0f, -0.1f, 0.0f, 0.0f);
        break;
    case AnalyticPrimitive::Cylinder: Q = float4x4(0.0f, 0.0f, 0.0f, 0.0f,
        0.0f, 1.0f, 0.0f, 0.0f,
        0.0f, 0.0f, 1.0f, 0.0f,
        0.0f, 0.0f, 0.0f, -1.0f);
        break;
    case AnalyticPrimitive::BigCylinder: Q = float4x4(1.0f, 0.0f, 0.0f, 0.0f,
        0.0f, 0.0f, 0.0f, 0.0f,
        0.0f, 0.0f, 1.0f, 0.0f,
        0.0f, 0.0f, 0.0f, -1.5f);
        break;
    case AnalyticPrimitive::SmallCylinder: Q = float4x4(1.0f, 0.0f, 0.0f, 0.0f,
        0.0f, 0.0f, 0.0f, 0.0f,
        0.0f, 0.0f, 1.0f, 0.0f,
        0.0f, 0.0f, 0.0f, -1.0f);
        break;
    case AnalyticPrimitive::SmallestCylinder: Q = float4x4(1.0f, 0.0f, 0.0f, 0.0f,
        0.0f, 0.0f, 0.0f, 0.0f,
        0.0f, 0.0f, 1.0f, 0.0f,
        0.0f, 0.0f, 0.0f, -0.3f);
        break;
    case AnalyticPrimitive::Cone: Q = float4x4 (-1.0f, 0.0f, 0.0f, 0.0f,
        0.0f, 1.0f, 0.0f, 0.0f,
        0.0f, 0.0f, -1.0f, 0.0f,
        0.0f, 0.0f, 0.0f, 0.0f);
        break;
    case AnalyticPrimitive::Sphere: Q = float4x4(1.0f, 0.0f, 0.0f, 0.0f,
        0.0f, 1.0f, 0.0f, 0.0f,
        0.0f, 0.0f, 1.0f, 0.0f,
        0.0f, 0.0f, 0.0f, -2.0f);
        break;
    default: return false;

    }
    float _thit;
    ProceduralPrimitiveAttributes _attr;

    float tquadMin = -1;
    float tquadMax = -1;
    bool quadricHit = false;
    if (QuadricRayIntersectionTestCSG(ray, minimum, tquadMin, tquadMax, _thit, _attr, type, Q))
    {
           
            hitFound = true;
      
            normal = _attr.normal;
    }

    float left_thit = -1;
    float right_thit = -1;
    bool rightPlaneI = false;
    bool leftPlaneI = false;
    ProceduralPrimitiveAttributes leftPlane, rightPlane;

   if (type == AnalyticPrimitive::Hyperboloid) {
        //intersect ray with planes at (1, 0,0), and (-1, 0, 0)
        if (rayPlaneCSGHyp(ray, left_thit, leftPlane, float3(1, 0, 0), 5, float3(-2, 0, 0), minimum)) {
            if ((_thit > left_thit) || (!hitFound)) {
                // tmin = left_thit;
                _thit = left_thit;
                normal = leftPlane.normal;
                hitFound = true;
                leftPlaneI = true;
            }
        }
        if (rayPlaneCSGHyp(ray, right_thit, rightPlane, float3(1, 0, 0), 5, float3(2, 0, 0), minimum)) {
            if ((_thit > right_thit) || (!hitFound)) {
                // tmin = right_thit;
                _thit = right_thit;
                normal = rightPlane.normal;
                hitFound = true;
                rightPlaneI = true;
            }
        }
    }


   if (type == AnalyticPrimitive::BigCylinder) {
       //intersect ray with planes at (1, 0,0), and (-1, 0, 0)
       if (rayPlaneCSG(ray, left_thit, leftPlane, float3(-1, 0, 0), 1.5, 1, minimum)) {
           if ((_thit > left_thit) || (!hitFound)) {
               // tmin = left_thit;
               _thit = left_thit;
               normal = leftPlane.normal;
               hitFound = true;
               leftPlaneI = true;
           }
       }
       if (rayPlaneCSG(ray, right_thit, rightPlane, float3(1, 0, 0), 1.5, -1, minimum)) {
           if ((_thit > right_thit) || (!hitFound)) {
               // tmin = right_thit;
               _thit = right_thit;
               normal = rightPlane.normal;
               hitFound = true;
               rightPlaneI = true;
           }
       }
   }

   if (type == AnalyticPrimitive::SmallCylinder) {
       //intersect ray with planes at (1, 0,0), and (-1, 0, 0)
       if (rayPlaneCSG(ray, left_thit, leftPlane, float3(0, 1, 0), 1, 1.5, minimum)) {
           if ((_thit > left_thit) || (!hitFound)) {
               // tmin = left_thit;
               _thit = left_thit;
               normal = leftPlane.normal;
               hitFound = true;
               leftPlaneI = true;
           }
       }
       if (rayPlaneCSG(ray, right_thit, rightPlane, float3(0, -1, 0), 1, -0.75, minimum)) {
           if ((_thit > right_thit) || (!hitFound)) {
               // tmin = right_thit;
               _thit = right_thit;
               normal = rightPlane.normal;
               hitFound = true;
               rightPlaneI = true;
           }
       }
   }

   /*if (type == AnalyticPrimitive::Cone) {
       //intersect ray with planes at (1, 0,0), and (-1, 0, 0)
       if (rayPlaneCSGCone(ray, left_thit, leftPlane, float3(1, 0, 0), 5, float3(0, -2, 0), minimum)) {
           if ((_thit > left_thit) || (!hitFound)) {
               // tmin = left_thit;
               _thit = left_thit;
               normal = leftPlane.normal;
               hitFound = true;
               leftPlaneI = true;
           }
       }
       if (rayPlaneCSGCone(ray, right_thit, rightPlane, float3(1, 0, 0), 5, float3(0, 3, 0), minimum)) {
           if ((_thit > right_thit) || (!hitFound)) {
               // tmin = right_thit;
               _thit = right_thit;
               normal = rightPlane.normal;
               hitFound = true;
               rightPlaneI = true;
           }
       }
   }*/


    if (hitFound) {
        quadricHit = true;
        thit = _thit;
        //normal = .normal;
    }
    return hitFound;

}

bool CSGRayTest(in Ray ray, out float tmin, out float tmax, inout float4 intervals, out float3 normal, in AnalyticPrimitive::Enum type) {

    //thit = RayTCurrent();

    float4x4 Q;
    bool hitFound = false;
    switch (type) {
    case AnalyticPrimitive::Hyperboloid: Q = float4x4(-1.0f, 0.0f, 0.0f, 0.0f,
        0.0f, 1.0f, 0.0f, 0.0f,
        0.0f, 0.0f, 1.0f, 0.0f,
        0.0f, 0.0f, 0.0f, -1.0f);
        break;
    case AnalyticPrimitive::Ellipsoid: Q = float4x4(1.0f / 1.5f, 0.0f, 0.0f, 0.0f,
        0.0f, 1.0f, 0.0f, 0.0f,
        0.0f, 0.0f, 1.0f / 2.0f, 0.0f,
        0.0f, 0.0f, 0.0f, -1.0f);
        break;
    case AnalyticPrimitive::Paraboloid: Q = float4x4 (1.0f / 2, 0.0f, 0.0f, 0.0f,
        0.0f, 0.0f, 0.0f, -0.1f,
        0.0f, 0.0f, 1.0f / 1.5f, 0.0f,
        0.0f, -0.1f, 0.0f, 0.0f);
        break;
    case AnalyticPrimitive::Cylinder: Q = float4x4(0.0f, 0.0f, 0.0f, 0.0f,
        0.0f, 1.0f, 0.0f, 0.0f,
        0.0f, 0.0f, 1.0f, 0.0f,
        0.0f, 0.0f, 0.0f, -1.0f);
        break;
    case AnalyticPrimitive::Cone: Q = float4x4 (-1.0f, 0.0f, 0.0f, 0.0f,
        0.0f, 1.0f, 0.0f, 0.0f,
        0.0f, 0.0f, -1.0f, 0.0f,
        0.0f, 0.0f, 0.0f, 0.0f);
        break;
    case AnalyticPrimitive::Sphere: Q = float4x4(1.0f, 0.0f, 0.0f, 0.0f,
        0.0f, 1.0f, 0.0f, 0.0f,
        0.0f, 0.0f, 1.0f, 0.0f,
        0.0f, 0.0f, 0.0f, -1.0f);
        break;
 
    default: return false;

    }
    float _thit;
    ProceduralPrimitiveAttributes _attr;

    float tquadMin = -1;
    float tquadMax = -1;
    bool quadricHit = false;
    if (QuadricRayIntersectionTest(ray, tquadMin, tquadMax, _thit, _attr, type, Q))
    {
        quadricHit = true;
       // thit = _thit;
        tmin = tquadMin;
        tmax = tquadMax;
        normal = _attr.normal;
        hitFound = true;

    }

    float left_thit = -1;
    float right_thit = -1;
   bool rightPlaneI = false;
   bool leftPlaneI = false;
    ProceduralPrimitiveAttributes leftPlane, rightPlane;
    /*if (type == AnalyticPrimitive::Hyperboloid) {
        //intersect ray with planes at (1, 0,0), and (-1, 0, 0)
        if (rayPlane(ray, left_thit, leftPlane, float3(1, 0, 0), 5, float3(-2, 0, 0))) {
            if ((_thit > left_thit) || (!hitFound)) {
                tmin = left_thit;
                _thit = left_thit;
                normal = leftPlane.normal;
                hitFound = true;
                leftPlaneI = true;
            }
        }
        if (rayPlane(ray, right_thit, rightPlane, float3(1, 0, 0), 5, float3(2, 0, 0))) {
            if ((_thit > right_thit) || (!hitFound)) {
                tmin = right_thit;
                normal =  rightPlane.normal;
                hitFound = true;
                rightPlaneI = true;
            }
        }
    }

    
    float4 intersections = float4(tquadMin, tquadMax, left_thit, right_thit);
    insertionSort(intersections);

    int count = 0;
    for (int i = 0; i < 4; i++) {
        if (intersections[i] > 0) {
            intervals[count] = intersections[i];
        }
    }*/
    //need to return float4 in sorted order
    return hitFound;

}


// Test if a ray with RayFlags and segment <RayTMin(), RayTCurrent()> intersects a hollow sphere.
bool RaySphereIntersectionTest(in Ray ray, out float thit, out float tmax, out ProceduralPrimitiveAttributes attr, in float3 center = float3(0, 0, 0), in float radius = 1)
{
    float t0, t1; // solutions for t if the ray intersects 

    if (!SolveRaySphereIntersectionEquation(ray, t0, t1, center, radius)) return false;
    tmax = t1;

    if (t0 < RayTMin())
    {
        // t0 is before RayTMin, let's use t1 instead .
        if (t1 < RayTMin()) return false; // both t0 and t1 are before RayTMin
        attr.normal = CalculateNormalForARaySphereHit(ray, t1, center);
        if (IsAValidHit(ray, t1, attr.normal))
        {
            
            thit = t1;
            return true;
        }
    }
    else
    {
        attr.normal = CalculateNormalForARaySphereHit(ray, t0, center);
        if (IsAValidHit(ray, t0, attr.normal))
        {   
            thit = t0;
            return true;
        }

        attr.normal = CalculateNormalForARaySphereHit(ray, t1, center);
        if (IsAValidHit(ray, t1, attr.normal))
        {
            thit = t1;
            return true;
        }
    }
    return false;
}



// Test if a ray segment <RayTMin(), RayTCurrent()> intersects a solid sphere.
// Limitation: this test does not take RayFlags into consideration and does not calculate a surface normal.
bool RaySolidSphereIntersectionTest(in Ray ray, out float thit, out float tmax, in float3 center = float3(0, 0, 0), in float radius = 1)
{
    float t0, t1; // solutions for t if the ray intersects 

    if (!SolveRaySphereIntersectionEquation(ray, t0, t1, center, radius))
        return false;

    // Since it's a solid sphere, clip intersection points to ray extents.
    thit = max(t0, RayTMin());
    tmax = min(t1, RayTCurrent());

    return true;
}


bool Intersection(float4 intersections, in float thit, in ProceduralPrimitiveAttributes first_attr, in ProceduralPrimitiveAttributes second_attr, inout ProceduralPrimitiveAttributes attr ) {
    if ((intersections.x < intersections.z) && (intersections.y > intersections.z))  {
        thit = intersections.z;
        attr = second_attr;
    }
    else if ((intersections.z < intersections.x) && (intersections.w > intersections.x)) {
        thit = intersections.x;
        attr = first_attr;
    }
    else {
        return false;
    }
    return true;
}

bool Union(float s_min, float b_min, out float thit, out ProceduralPrimitiveAttributes attr) {
    thit = min(s_min, b_min);
  
    return true;
}
bool ConstructiveSolidGeometry(in Ray ray, out float thit, out ProceduralPrimitiveAttributes attr) {
    //get intersections for both AABB, and sphere.
    float s_tmin, s_tmax;
    float b_tmin, b_tmax;
    float t_hit;
    ProceduralPrimitiveAttributes s_attr;
    ProceduralPrimitiveAttributes b_attr;
  /*float4x4 Q = float4x4(-1.0f, 0.0f, 0.0f, 0.0f,
        0.0f, 1.0f, 0.0f, 0.0f,
        0.0f, 0.0f, 1.0f, 0.0f,
        0.0f, 0.0f, 0.0f, -0.9f);
        */
    float4x4 Q = float4x4 (-1.0f, 0.0f, 0.0f, 0.0f,
        0.0f, 1.0f, 0.0f, 0.0f,
        0.0f, 0.0f, -1.0f, 0.0f,
        0.0f, 0.0f, 0.0f, 0.0f);

   bool sphere_hit = RaySphereIntersectionTest(ray, s_tmin, s_tmax, s_attr);
   bool hyp_hit = QuadricRayIntersectionTest(ray, b_tmin, b_tmax, t_hit, b_attr, AnalyticPrimitive::Enum::Cone, Q);
    if (sphere_hit || hyp_hit) {
        if (sphere_hit && hyp_hit) {
            float2 diffs;

            diffs.x = s_tmin;
            diffs.y = t_hit;
            bool hit = Union(s_tmin, t_hit, thit, attr);
            float3 intersectionPoint = ray.origin + thit * ray.direction;
            // thit = t_hit;
            // attr.normal = CalculateNormalForARayQuadricHit(ray, t_hit, Q);
            if (thit == s_tmin) {
                attr = s_attr;
            }
            else {
                attr = b_attr;
            }
        }
        else if (sphere_hit && !hyp_hit) {
            thit = s_tmin;
            attr = s_attr;
        }
        else {
            thit = b_tmin;
            attr = b_attr;
        }
        return true;
    
    }

    return false;
    
    //turn true;
}

bool ConstructiveSolidGeometry_I(in Ray ray, out float thit, out ProceduralPrimitiveAttributes attr) {
    //get intersections for both AABB, and sphere.
    float s_tmin, s_tmax;
    float b_tmin, b_tmax;
    float t_hit;    
    float4 intersections;


    ProceduralPrimitiveAttributes s_attr;
    ProceduralPrimitiveAttributes b_attr;
   
    float4x4 Q = float4x4 (-1.0f, 0.0f, 0.0f, 0.0f,
        0.0f, 1.0f, 0.0f, 0.0f,
        0.0f, 0.0f, -1.0f, 0.0f,
        0.0f, 0.0f, 0.0f, 0.0f);

    bool sphere_hit = RaySphereIntersectionTest(ray, s_tmin, s_tmax, s_attr);
    bool hyp_hit = QuadricRayIntersectionTest(ray, b_tmin, b_tmax, t_hit, b_attr, AnalyticPrimitive::Enum::Cone, Q);

    if (sphere_hit && hyp_hit) {
        intersections = float4(s_tmin, s_tmax, b_tmin, b_tmax);
        float e = max(intersections.x, intersections.z);
        float f = min(intersections.y, intersections.w);
        if (e <= f) {
            if (e == intersections.x) {
                attr = s_attr;
            }
            else {
                attr = b_attr;
            }
            if (RayTMin() < e) {
                thit = e;
            }
            else {
                thit = f;
            }
            return true;
            //attr = s_attr;
        }
        //return Intersection(intersections, thit, s_attr, b_attr, attr);
    }

    return false;


//turn true;
}


bool ConstructiveSolidGeometry_D(in Ray ray, out float thit, out ProceduralPrimitiveAttributes attr) {
    //get intersections for both AABB, and sphere.
    float s_tmin, s_tmax;
    float b_tmin, b_tmax;
    float t_hit;
    float4 intersections;


    ProceduralPrimitiveAttributes s_attr;
    ProceduralPrimitiveAttributes b_attr;
    float4x4 Q = float4x4 (-1.0f, 0.0f, 0.0f, 0.0f,
        0.0f, 1.0f, 0.0f, 0.0f,
        0.0f, 0.0f, -1.0f, 0.0f,
        0.0f, 0.0f, 0.0f, 0.0f);

    bool sphere_hit = RaySphereIntersectionTest(ray, s_tmin, s_tmax, s_attr);
    bool hyp_hit = QuadricRayIntersectionTest(ray, b_tmin, b_tmax, t_hit, b_attr, AnalyticPrimitive::Enum::Cone, Q);

    if (sphere_hit && hyp_hit) {
        intersections = float4(b_tmin, b_tmax, s_tmin, s_tmax);
        if (intersections.x < intersections.z) {
            thit = intersections.x;
            attr = b_attr;
        }
        else if (intersections.w < intersections.y) {
            thit = intersections.w;
            attr.normal = -s_attr.normal;
        }
        else {
            return false;
        }

        return true;
        //return Intersection(intersections, thit, s_attr, b_attr, attr);
    }

    if (hyp_hit) {
        thit = t_hit;
        attr = b_attr;
        return true;
    }
    return false;


    //turn true;
}



// Test if a ray with RayFlags and segment <RayTMin(), RayTCurrent()> intersects multiple hollow spheres.
bool RaySpheresIntersectionTest(in Ray ray, out float thit, out ProceduralPrimitiveAttributes attr)
{
    const int N = 4;
    float3 centers[N] =
    {
        float3(-0.3, -0.3, -0.3),
        float3(0.1, 0.1, 0.4),
        float3(0.35,0.35, 0.0),
        float3(0.5,0.5, 1)

    };
    float  radii[N] = { 1, 0.2, 0.15, 0.5 };
    bool hitFound = false;

    //
    // Test for intersection against all spheres and take the closest hit.
    //
    thit = RayTCurrent();

    float _thit;
    float _tmax;
    ProceduralPrimitiveAttributes _attr;
    // for (int i = 0; i < N; i++) {
    if (RaySphereIntersectionTest(ray, _thit, _tmax, _attr, centers[0], radii[0]))
    {
        if (_thit < thit)
        {
            thit = _thit;
            attr = _attr;
            hitFound = true;
        }
    }
    //  }
    return hitFound;

}


bool cubeIntersection(Ray r, inout float thit, out ProceduralPrimitiveAttributes attr) {


    float eps = 0.000001;

    //this conditional makes sure we will not divide by zero in any of the cases, or get rounding errors.
    if (abs(r.direction.x) < eps || abs(r.direction.y) < eps || abs(r.direction.z) < eps) {
        return false;
    }
    //r.direction = normalize(r.direction)
    float hits[6];
    float3 normals[6];
    float t1;
    float t2;
    float t3;
    float t4;
    float t5;
    float t6;

    int counter = 0;
    //tests for the plane where z components = 1
    t1 = (1 - r.origin.z) / r.direction.z;
    //if the intersection is greater than zero (in front of the camera) and if x, y components are in range [-1, 1] we have a hit.
    if (t1 > 0) {

        float3 hit = r.origin + t1 * r.direction;

        if ((abs(hit.x) <= 1) && (abs(hit.y) <= 1)) {
            hits[counter] = t1;
            normals[counter] = float3(0, 0, 1);

            counter++;
        }
    }
    //tests for the plane where z components = -1
    t2 = (-1 - r.origin.z) / r.direction.z;
    //if the intersection is greater than zero (in front of the camera) and if x, y components are in range [-1, 1] we have a hit.
    if (t2 > 0) {
        float3 hit = r.origin + t2 * r.direction;
        if ((abs(hit.x) <= 1) && (abs(hit.y) <= 1)) {
            hits[counter] = t2;
            normals[counter] = float3(0, 0, -1);
            counter++;
        }
    }
    //tests for the plane where y components = 1
    t3 = (1 - r.origin.y) / r.direction.y;
    if (t3 > 0) {
        //if the intersection is greater than zero (in front of the camera) and if x, z components are in range [-1, 1] we have a hit.
        float3 hit = r.origin + t3 * r.direction;
        if ((abs(hit.x) <= 1) && (abs(hit.z) <= 1)) {
            hits[counter] = t3;
            normals[counter] = float3(0, 1, 0);
            counter++;
        }
    }

    //tests for the plane where y components = -1
    t4 = (-1 - r.origin.y) / r.direction.y;
    if (t4 > 0) {
        //if the intersection is greater than zero (in front of the camera) and if x, z components are in range [-1, 1] we have a hit.
        float3 hit = r.origin + t4 * r.direction;
        if ((abs(hit.x) <= 1) && (abs(hit.z) <= 1)) {
            hits[counter] = t4;
            normals[counter] = float3(0, 1, 0);
            counter++;
        }
    }
    //tests for the plane where x components = 1
    t5 = (1 - r.origin.x) / r.direction.x;
    if (t5 > 0) {
        //if the intersection is greater than zero (in front of the camera) and if y, z components are in range [-1, 1] we have a hit.
        float3 hit = r.origin + t5 * r.direction;

        if ((abs(hit.y) <= 1) && (abs(hit.z) <= 1)) {
            hits[counter] = t5;
            normals[counter] = float3(1, 0, 0);
            counter++;
        }
    }

    //tests for the plane where x components = -1
    t6 = (-1 - r.origin.x) / r.direction.x;
    if (t6 > 0) {
        //if the intersection is greater than zero (in front of the camera) and if y, z components are in range [-1, 1] we have a hit.
        float3 hit = r.origin + t6 * r.direction;
        if ((abs(hit.y) <= 1) && (abs(hit.z) <= 1)) {
            hits[counter] = t6;
            normals[counter] = float3(1, 0, 0);
            counter++;
        }
    }

    if (counter == 0) {
        return false;
    }
    float tmin = 100000;
    float tmax = -1;
    float3 minNormal;
    float3 maxNormal;

    for (int i = 0; i < counter; i++) {
        if (hits[i] < tmin) {
            tmin = hits[i];
            minNormal = normals[i];
        }
        if (hits[i] > tmax) {
            tmax = hits[i];
            maxNormal = normals[i];
        }
    }

    thit = tmin;
         if (tmin < RayTMin() || tmin > RayTCurrent() )
            return false;
   // float3 hit = ray.origin + thit * r.direction;
    if (dot(minNormal, r.direction) > 0) {
        minNormal = -minNormal;
    }
    
    attr.normal = minNormal;
    return true;
    // return result;
}

// Test if a ray segment <RayTMin(), RayTCurrent()> intersects an AABB.
// Limitation: this test does not take RayFlags into consideration and does not calculate a surface normal.
// Ref: https://www.scratchapixel.com/lessons/3d-basic-rendering/minimal-ray-tracer-rendering-simple-shapes/ray-box-intersection
bool RayAABBIntersectionTest(Ray ray, float3 aabb[2], out float tmin, out float tmax)
{
    float3 tmin3, tmax3;
    int3 sign3 = ray.direction > 0;

    // Handle rays parallel to any x|y|z slabs of the AABB.
    // If a ray is within the parallel slabs, 
    //  the tmin, tmax will get set to -inf and +inf
    //  which will get ignored on tmin/tmax = max/min.
    // If a ray is outside the parallel slabs, -inf/+inf will
    //  make tmax > tmin fail (i.e. no intersection).
    // TODO: handle cases where ray origin is within a slab 
    //  that a ray direction is parallel to. In that case
    //  0 * INF => NaN
    const float FLT_INFINITY = 1.#INF;
   //float3 invRayDirection = 1/ray.direction;
    float3 invRayDirection = ray.direction != 0 
                           ? 1 / ray.direction 
                           : (ray.direction > 0) ? FLT_INFINITY : -FLT_INFINITY;
                         
    tmin3.x = (aabb[1 - sign3.x].x - ray.origin.x) * invRayDirection.x;
    tmax3.x = (aabb[sign3.x].x - ray.origin.x) * invRayDirection.x;

    tmin3.y = (aabb[1 - sign3.y].y - ray.origin.y) * invRayDirection.y;
    tmax3.y = (aabb[sign3.y].y - ray.origin.y) * invRayDirection.y;
    
    tmin3.z = (aabb[1 - sign3.z].z - ray.origin.z) * invRayDirection.z;
    tmax3.z = (aabb[sign3.z].z - ray.origin.z) * invRayDirection.z;
    
    tmin = max(max(tmin3.x, tmin3.y), tmin3.z);
    tmax = min(min(tmax3.x, tmax3.y), tmax3.z);
    
    return tmax > tmin;
}

bool RayAABBTest(Ray ray, float3 aabb[2], inout float tmin, inout  float tmax) {
    return true;
}

// Test if a ray with RayFlags and segment <RayTMin(), RayTCurrent()> intersects a hollow AABB.
bool RayAABBIntersectionTest(Ray ray, float3 aabb[2], out float thit, out ProceduralPrimitiveAttributes attr)
{
    float tmin, tmax;
    if (RayAABBIntersectionTest(ray, aabb, tmin, tmax))
    {
        // Only consider intersections crossing the surface from the outside.
        if (tmin < RayTMin() || tmin > RayTCurrent() )
           // return false;

            if (tmin < RayTMin()) {
                if (tmax < RayTMin()) {
                    return false;
                }
                else {
                    thit = tmax;
                }
            }
            else {
                thit = tmin;
            }
        // Set a normal to the normal of a face the hit point lays on.
        float3 hitPosition = ray.origin + thit * ray.direction;
        float3 distanceToBounds[2] = {
            abs(aabb[0] - hitPosition),
            abs(aabb[1] - hitPosition)
        };
        const float eps = 0.0001;
        if (distanceToBounds[0].x < eps) attr.normal = float3(-1, 0, 0);
        else if (distanceToBounds[0].y < eps) attr.normal = float3(0, -1, 0);
        else if (distanceToBounds[0].z < eps) attr.normal = float3(0, 0, -1);
        else if (distanceToBounds[1].x < eps) attr.normal = float3(1, 0, 0);
        else if (distanceToBounds[1].y < eps) attr.normal = float3(0, 1, 0);
        else if (distanceToBounds[1].z < eps) attr.normal = float3(0, 0, 1);

        if (dot(ray.direction, attr.normal) > 0) {
            attr.normal = -attr.normal;
        }
        return true;
       //return IsAValidHit(ray, thit, attr.normal);
    }
    return false;
}

bool RayAABBIntersectionTestCSG(Ray ray, float3 aabb[2], in float minimum, out float thit, out ProceduralPrimitiveAttributes attr)
{
    float tmin, tmax;
    if (RayAABBIntersectionTest(ray, aabb, tmin, tmax))
    {
        // Only consider intersections crossing the surface from the outside.
      
        thit = tmin;

        if (tmin < minimum) {
            if (tmax < minimum) {
                return false;
            }
            else {
                thit = tmax;
            }
        }


        // Set a normal to the normal of a face the hit point lays on.
        float3 hitPosition = ray.origin + thit * ray.direction;
        float3 distanceToBounds[2] = {
            abs(aabb[0] - hitPosition),
            abs(aabb[1] - hitPosition)
        };
        const float eps = 0.0001;
        if (distanceToBounds[0].x < eps) attr.normal = float3(-1, 0, 0);
        else if (distanceToBounds[0].y < eps) attr.normal = float3(0, -1, 0);
        else if (distanceToBounds[0].z < eps) attr.normal = float3(0, 0, -1);
        else if (distanceToBounds[1].x < eps) attr.normal = float3(1, 0, 0);
        else if (distanceToBounds[1].y < eps) attr.normal = float3(0, 1, 0);
        else if (distanceToBounds[1].z < eps) attr.normal = float3(0, 0, 1);

       // if (dot(ray.direction, attr.normal) > 0) {
         //   attr.normal = -attr.normal;
        //}
        return true;
        //return IsAValidHit(ray, thit, attr.normal);
    }
    return false;
}


#endif // ANALYTICPRIMITIVES_H