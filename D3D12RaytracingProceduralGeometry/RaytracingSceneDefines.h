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

#pragma once

#include "RayTracingHlslCompat.h"

namespace GlobalRootSignature {
    namespace Slot {
        enum Enum {
            OutputView = 0,
            RasterView,
            PhotonBuffer,
            TiledPhotonMap,
            SceenSpaceMap,
            AccelerationStructure,
            SceneConstant,
            AABBattributeBuffer,
            VertexBuffers,
            CSGTree,
            Count
        };
    }
}

//for forward and backward bidirectional path-tracing
namespace GlobalRootSignature_Bidirectional {
    namespace Slot {
        enum Enum {
            OutputView = 0,
            StagingTarget,
            LightAccumulationBuffer,
            ForwardAccumulationBuffer,
            LightVertices,
            AccelerationStructure,
            SceneConstant,
            AABBattributeBuffer,
            VertexBuffers,
            CSGTree,
            Count
        };
    }
}
namespace GlobalRootSignature_BidirectionalLight {
    namespace Slot {
        enum Enum {
            OutputView = 0,
            StagingTarget,
            LightVertices,
            AccelerationStructure,
            SceneConstant,
            AABBattributeBuffer,
            VertexBuffers,
            CSGTree,
            Count
        };
    }
}
namespace GlobalRootSignature_NoScreenSpaceMap {
    namespace Slot {
        enum Enum {
            OutputView = 0,
            RasterView,
            PhotonBuffer,
            PhotonCounter,
            GBuffer,
            AccelerationStructure,
            SceneConstant,
            AABBattributeBuffer,
            VertexBuffers,
            CSGTree,
            TiledPhotonMap,

            Count
        };
    }
}
namespace ComputeCompositeRootSignature {
    namespace Slot {
        enum Enum {
            RayTracingView = 0,
            RasterView = 1,
            Count
        };
    }
}

namespace PhotonGlobalRoot {
    namespace Slot {
        enum Enum {
            OutputView = 0,
            RasterView,
            PhotonBuffer,
            PhotonCounter,
            ScreenSpaceMap,
            AccelerationStructure,
            SceneConstant,
            AABBattributeBuffer,
            VertexBuffers,
            CSGTree,
            Count
        };
    }
}


namespace PhotonGlobalRoot_NoScreenSpaceMap {
    namespace Slot {
        enum Enum {
            OutputView = 0,
            RasterView,
            PhotonBuffer,
            PhotonCounter,
            AccelerationStructure,
            SceneConstant,
            AABBattributeBuffer,
            VertexBuffers,
            CSGTree,
            Count
        };
    }
}


namespace RasterisationRootSignature {
    namespace Slot {
        enum Enum {
            OutputView = 0,
            PhotonBuffer,
            GBuffer,
            RasterTarget,
            Constant,
            Count
        };
    }
}


namespace ComputeRootSignatureParams
{
    enum Value
    {
        OutputViewSlot = 0,
        PhotonBuffer,
        TiledPhotonMap,
        ParamConstantBuffer,
        Count
    };
}


namespace LocalRootSignature {
    namespace Type {
        enum Enum {
            Triangle = 0,
            AABB,
            Count
        };
    }
}

namespace LocalRootSignature {
    namespace Triangle {
        namespace Slot {
            enum Enum {
                MaterialConstant = 0,
                Count
            };
        }
        struct RootArguments {
            PrimitiveConstantBuffer materialCb;
        };
    }
}

namespace LocalRootSignature {
    namespace AABB {
        namespace Slot {
            enum Enum {
                MaterialConstant = 0,
                GeometryIndex,
                Count
            };
        }
        struct RootArguments {
            PrimitiveConstantBuffer materialCb;
            PrimitiveInstanceConstantBuffer aabbCB;
        };
    }
}

namespace LocalRootSignature {
    inline UINT MaxRootArgumentsSize()
    {
        return max(sizeof(Triangle::RootArguments), sizeof(AABB::RootArguments));
    }
}

namespace GeometryType {
    enum Enum {
        Triangle = 0,
        AABB,       // Procedural geometry with an application provided AABB.
        Count
    };
}

namespace GpuTimers {
    enum Enum {
        Raytracing = 0,
        Count
    };
}

// Bottom-level acceleration structures (BottomLevelASType).
// This sample uses two BottomLevelASType, one for AABB and one for Triangle geometry.
// Mixing of geometry types within a BLAS is not supported.
namespace BottomLevelASType = GeometryType;


namespace IntersectionShaderType {
    enum Enum {
        AnalyticPrimitive = 0,
        VolumetricPrimitive,
        SignedDistancePrimitive,
       CSG,
        Count
    };
    inline UINT PerPrimitiveTypeCount(Enum type)
    {
        switch (type)
        {
        case AnalyticPrimitive: return AnalyticPrimitive::Count;
        case VolumetricPrimitive: return VolumetricPrimitive::Count;
        case SignedDistancePrimitive: return SignedDistancePrimitive::Count;
        case CSG: return CSGPrimitive::Count;

        }
        return 0;
    }
    static const UINT MaxPerPrimitiveTypeCount =
        max(AnalyticPrimitive::Count, max(VolumetricPrimitive::Count, SignedDistancePrimitive::Count));
    static const UINT TotalPrimitiveCount =
        AnalyticPrimitive::Count + VolumetricPrimitive::Count + SignedDistancePrimitive::Count + CSGPrimitive::Count;
}

