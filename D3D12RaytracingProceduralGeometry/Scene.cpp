#include "stdafx.h"
#include "Scene.h"

void Scene::keyPress(UINT8 key)
{
   camera->OnKeyDown(key);

    switch (key) {
        case 'N':
            m_sceneCB->renderFull = !m_sceneCB->renderFull;
            break;
        case '1':
            m_sceneCB->index = 0;
            break;
        case '2':
            m_sceneCB->index = 1;
            break;
        case '3':
            m_sceneCB->index = 2;
            break;
        case '4':
            m_sceneCB->index = 3;
            break;
        case '5':
            m_sceneCB->index = 4;
            break;
        case '6':
            m_sceneCB->index = 5;
            break;
        case '7':
            m_sceneCB->index = 6;
            break;
    }

  
}

void Scene::mouseMove(float dx, float dy)
{
   camera->OnMouseMove(dx, dy);
}

Scene::Scene(std::unique_ptr<DX::DeviceResources> &m_deviceResources)
{
    //initialise the scene constant buffer
    auto device = m_deviceResources->GetD3DDevice();
    auto frameCount = m_deviceResources->GetBackBufferCount();

    m_sceneCB.Create(device, frameCount, L"Scene Constant Buffer");
    m_sceneCB->accumulatedFrames = 0;
    m_sceneCB->spp = 12;
    m_sceneCB->frameNumber = frameCount;
    m_sceneCB->renderFull = true;
    srand((unsigned int)time(NULL));
    m_sceneCB->index = 0;
    m_sceneCB->rand1 = rand();
    m_sceneCB->rand2 = rand() % 1000000;
    m_sceneCB->rand3 = rand() % 1000000;
    m_sceneCB->rand4 = rand() % 1000000;
}


XMMATRIX Scene::GetMVP() {
    return camera->getMVP();
}

void Scene::Init(float m_aspectRatio)
{
  
    if (!instancing) {
        CreateGeometry();
        //NUM_BLAS = 2;
        NUM_BLAS = 2;
    }
    else {

        if (!triangleInstancing && !albany) {
            CreateGeometry();
           // CreateSpheres();
        }
         //CreateSpheres();
        
        // coordinates->translateCloud(Eigen::Vector3d(0.0, 0.0, 0.0));
          //because triangle geometry can't be stored in the procedural geometry BLAS, we add +1
         if (albany) {
             CreateSpheres();

             coordinates = new PlyFile("/Models/Main_Room_Dense_Filtered_100_thousand.ply");
             coordinates->translateToOrigin(coordinates->centroid());
             NUM_BLAS = coordinates->size() + 1;
         }
         else {
             NUM_BLAS = 10;
         }
    }
        auto SetAttributes = [&](
            UINT primitiveIndex,
            const XMFLOAT4& albedo,
            float reflectanceCoef = 0.0f,
            float refractiveCoef = 0.0f,
            float diffuseCoef = 0.9f,
            float specularCoef = 0.7f,
            float specularPower = 50.0f,
            float stepScale = 1.0f
            )
        {
            auto& attributes = m_aabbMaterialCB[primitiveIndex];
            attributes.albedo = albedo;
            attributes.reflectanceCoef = reflectanceCoef;
            attributes.refractiveCoef = refractiveCoef;
            attributes.diffuseCoef = diffuseCoef;
            attributes.specularCoef = specularCoef;
            attributes.specularPower = specularPower;
            attributes.stepScale = stepScale;
        };

    

    
    // Albedos
    XMFLOAT4 green = XMFLOAT4(0.1f, 1.0f, 0.5f, 1.0f);
    XMFLOAT4 grey = XMFLOAT4(0.6, 0.6, 0.6, 0);
    XMFLOAT4 yellow = XMFLOAT4(1.0f, 1.0f, 0.5f, 1.0f);
    m_planeMaterialCB = {grey, 0, 0,  1, 0.4f, 50, 1 };

    UINT offset = 0;
    // Analytic primitives.
    {
        float X = 1.0f;
        using namespace AnalyticPrimitive;
        for (Primitive& p : analyticalObjects) {
            PrimitiveConstantBuffer material = p.getMaterial();
            SetAttributes(offset + p.getType(), material.albedo, material.reflectanceCoef, material.refractiveCoef, material.diffuseCoef, material.specularCoef, material.specularPower, material.stepScale);
        }
        offset += AnalyticPrimitive::Count + 1;
    }

    
       
    {
            using namespace SignedDistancePrimitive;

        if (quatJulia) {
            SetAttributes(offset + QuaternionJulia, XMFLOAT4(0.9f, 0.5f , 0.5f, 0), 0, 1.7f, 0.1f, 1.0f, 50, 1.0f);

        }
        if (bloobs) {
            SetAttributes(offset + MetaBalls, XMFLOAT4(0.8, 0.0, 0, 0), 0, 1.7f, 0.0f, 1, 50, 1.0f);

        }
        offset += SignedDistancePrimitive::Count;

    }
  //  XMFLOAT4(0.94901960784
    //    , 0.75294117647
      //  , 0.81960784314, 0),

    {

        if (CSG) {
            using namespace CSGPrimitive;
            SetAttributes(offset + CSGPrimitive::CSG, XMFLOAT4(0.6f
                , 0.0f
                , 0.0f, 0), 0, 1.7f, 0.0f, 1.0f, 50, 1.0f);
        }
    }

    // Setup camera.
    {
        camera = new Camera(m_aspectRatio);
    }

    {
        Geometry torus;
        torus.LoadModel("/Models/sub_1.obj");
        Geometry plane;
        plane.initPlane();
        this->plane = false;
        if (triangleInstancing) {
            meshes = { torus };
        }
        else{
            this->plane = true;

           meshes = { plane };
        }

    }

// Setup lights.
    {
        // Initialize the lighting parameters.
        XMFLOAT4 lightPosition;
        XMFLOAT4 lightAmbientColor;
        XMFLOAT4 lightDiffuseColor;
        XMFLOAT4 lightSphere;
        //2.0f, -0.36, 0
        //10, 18, 5
      //  -1, -0.4f, 2.0f
        //lightSphere = XMFLOAT4(0.0f, 18.0f, -20.0f, 0.5f);
       //lightSphere = XMFLOAT4(10, 18, -0.0f, 0.5);
      // lightSphere = XMFLOAT4()1.00545
       lightSphere = XMFLOAT4(4.07625, 5.90386, 1.00545, 0.0f);
       // lightSphere = XMFLOAT4(6.0f, 10, 12, 0.0f);
        lightPosition = XMFLOAT4(10, 10, -10, 0.0f);
        m_sceneCB->lightPosition = XMLoadFloat4(&lightPosition);
        m_sceneCB->lightSphere = XMLoadFloat4(&lightSphere);
        m_sceneCB->lightPower = 1;
        lightAmbientColor = XMFLOAT4(0, 1, 1, 1.0f);
        m_sceneCB->lightAmbientColor = XMLoadFloat4(&lightAmbientColor);
         
        float d = 1;
        lightDiffuseColor = XMFLOAT4(d, d, d, d);
        m_sceneCB->lightDiffuseColor = XMLoadFloat4(&lightDiffuseColor);
    }
}


void Scene::convertCSGToArray(int numberOfNodes, std::unique_ptr<DX::DeviceResources>& m_deviceResources) {
  //  auto device = m_deviceResources->GetD3DDevice();
    auto SetNodeValues = [&](int index, int leftNode, int rightNode, int boolValue, int parentIndex, int geometry, XMFLOAT3 translation) {
        csgTree[index].boolValue = boolValue;
        csgTree[index].leftNodeIndex = leftNode;
        csgTree[index].rightNodeIndex = rightNode;
        csgTree[index].geometry = geometry;
        csgTree[index].parentIndex = parentIndex;
        csgTree[index].myIndex = index;
        csgTree[index].translation = translation;
    };
   
    /*SetNodeValues(0, -1, -1, -1, -1, 6, XMFLOAT3(0, 0, 0));
    SetNodeValues(1, -1, -1, -1, -1, 3, XMFLOAT3(0,0, 0));
    SetNodeValues(2, -1, -1, 1, -1, -1, XMFLOAT3(0, 0, 0));
    SetNodeValues(4, -1, -1, -1, -1 ,21, XMFLOAT3(0, 2, 0));
    SetNodeValues(5, -1, -1, 0, -1 ,-1, XMFLOAT3(0, 0, 0));

    m_sceneCB->csgNodes = 6;
   // SetNodeValues(0, -1, -1, -1, -1, 3, XMFLOAT3(0, 0, 0));
    //SetNodeValues(1, -1, -1, -1, 1, 3, XMFLOAT3(0.5, 0.5, 0));
    //SetNodeValues(2, 0, 1,1, 1, -1, XMFLOAT3(0, 0, 0));
    //COFFEE MUG
   */
    SetNodeValues(0, -1, -1, -1, 1, 17, XMFLOAT3(0, 0, 0));
    SetNodeValues(1, -1, -1, -1, 1, 18, XMFLOAT3(0, 0.2, 0));
    SetNodeValues(2, -1, -1, 2, -1, -1, XMFLOAT3(0, 0, 0));
    SetNodeValues(3, -1, -1, -1, 1, 9, XMFLOAT3(1.1, 0, 0));
    SetNodeValues(4, -1, -1, -1, 1, 0, XMFLOAT3(1.1, 0.0, 0));
    SetNodeValues(5, -1, -1, 2, -1, -1, XMFLOAT3(0, 0, 0));
    SetNodeValues(6, -1, -1, 0, -1, -1, XMFLOAT3(0, 0, 0));
    m_sceneCB->csgNodes = 7;

   


    //SetNodeValues(3, -1, -1, -1, 1, 0, XMFLOAT3(0.05, 0, 0));
   // SetNodeValues(4, -1, -1, -1, 1, 9, XMFLOAT3(0.05, 0, 0));
   // SetNodeValues(5, -1, -1, -1, 2, -1, XMFLOAT3(0, 0, 0));
   // SetNodeValues(6, -1, -1, -1, 0, -1, XMFLOAT3(0, 0, 0));

 //   SetNodeValues(3, -1, -1, -1, -1, 3, XMFLOAT3(0, 0, 0));
  //  SetNodeValues(4, -1, -1, -1, -1, 8, XMFLOAT3(0, 0, 0));
   // SetNodeValues(5, -1, -1, 1, -1, -1, XMFLOAT3(0, 0, 0));
    //SetNodeValues(6, -1, -1, 0, -1, -1, XMFLOAT3(0, 0, 0));

   // SetNodeValues(5, -1, -1, -1, -1, 5, XMFLOAT3(0, 0, 0));
    //SetNodeValues(6, -1, -1, 1, -1, -1, XMFLOAT3(0, 0, 0));

   /* SetNodeValues(0, -1, -1, -1, 1, 3, XMFLOAT3(1, 0, 0));
    SetNodeValues(1, -1, -1, -1, 1, 3, XMFLOAT3(2, 3, 0));
    SetNodeValues(2, -1, -1, 0, 1, 3, XMFLOAT3(1, 2, 0));
    SetNodeValues(3, -1, -1, -1, 1, 3, XMFLOAT3(1, 4, 0));
    SetNodeValues(4, -1, -1, 0, 1, 3, XMFLOAT3(2, 1, 3));
    SetNodeValues(5, -1, -1, -1, 1, 0, XMFLOAT3(0.1, 0.5, 0));
    SetNodeValues(6, -1, -1, 1, 0, -1, XMFLOAT3(0.3, 0.4, 0));
    */
    //m_sceneCB->csgNodes = 7;
   // U(HyperBoloid, Sphere) Intersection U(Cone, Ellipsoid)
    /**
     int boolValue;
    //pertains to the geometry described by the AABB encodings
    int geometry;
    int parentIndex;
    int leftNodeIndex;
    int rightNodeIndex;
    UINT myIndex;*/

   /* SetNodeValues(0, 1, 2, 1, -1, -1, XMFLOAT3(0,0,0));
    SetNodeValues(1, 3, 4, 1, 0, -1, XMFLOAT3(0, 0, 0));
    SetNodeValues(2, 5, 6, 1, 0, -1, XMFLOAT3(0, 0, 0));
    SetNodeValues(3, -1, -1, -1, 1, 2, XMFLOAT3(0, 0, 0));
    SetNodeValues(4, -1, -1, -1, 1, 7, XMFLOAT3(0, 0, 0));
    SetNodeValues(5, -1, -1, -1, 2, 5, XMFLOAT3(0, 0, 0));
    SetNodeValues(6, -1, -1, -1, 2, 4, XMFLOAT3(0, 0, 0));
    /**
    
    SetNodeValues(0, 1, 2, 1, -1, -1);
    SetNodeValues(2, -1, -1, -1, 0, 5);
    SetNodeValues(1, 3, 4, 2, 0, -1);
    SetNodeValues(3, -1, -1, -1, 1, 2);
    SetNodeValues(4, -1, -1, -1, 1, 3);

  /*  SetNodeValues(0, 1, 2, 1, -1, -1);
    SetNodeValues(1, 3, 4, 0, 0, -1);
    SetNodeValues(2, -1, -1, -1, 0, 7);
    SetNodeValues(3, -1, -1, -1, 1, 2);
    SetNodeValues(4, -1, -1, -1, 1, 3);*/
   
   // AllocateUploadBuffer(device, csgTree.data(), csgTree.size() * sizeof(csgTree[0]), &csgTree.resource);

}


void Scene::UpdateAABBPrimitiveAttributes(float animationTime, bool animate, std::unique_ptr<DX::DeviceResources>& m_deviceResources)
{
    auto frameIndex = m_deviceResources->GetCurrentFrameIndex();
    
   if (!animate) {
        animationTime = previousRot;
        previousRot = animationTime;

   }
   else {
       previousRot = animationTime;
   }
    XMMATRIX mIdentity = XMMatrixIdentity();

    XMMATRIX mScale15y = XMMatrixScaling(1, 1.5, 1);
    XMMATRIX mScale15 = XMMatrixScaling(1.5, 1.5, 1.5);
    XMMATRIX mScaleHalf = XMMatrixScaling(0.2, 0.2, 0.2);
    XMMATRIX mScaleTiny = XMMatrixScaling(0.05, 0.05, 0.05);

    XMMATRIX mScale2 = XMMatrixScaling(2, 2, 2);
    XMMATRIX mScale3 = XMMatrixScaling(3, 3, 3);
    XMMATRIX massive = XMMatrixScaling(10, 10, 10);

   
    XMMATRIX mRotation = XMMatrixRotationY(-2 * animationTime);
    XMMATRIX hypRot = XMMatrixRotationY(-0.5*animationTime);
    XMMATRIX cup = XMMatrixRotationY(0);

    // Apply scale, rotation and translation transforms.
    // The intersection shader tests in this sample work with local space, so here
    // we apply the BLAS object space translation that was passed to geometry descs.
    auto SetTransformForAABB = [&](UINT primitiveIndex, XMMATRIX& mScale, XMMATRIX& mRotation)
    {
        XMVECTOR vTranslation =
            0.5f * (XMLoadFloat3(reinterpret_cast<XMFLOAT3*>(&m_aabbs[primitiveIndex].MinX))
                + XMLoadFloat3(reinterpret_cast<XMFLOAT3*>(&m_aabbs[primitiveIndex].MaxX)));
        XMMATRIX mTranslation = XMMatrixTranslationFromVector(vTranslation);

        XMMATRIX mTransform = mScale * mRotation * mTranslation;
        m_aabbPrimitiveAttributeBuffer[primitiveIndex].localSpaceToBottomLevelAS = mTransform;
        m_aabbPrimitiveAttributeBuffer[primitiveIndex].bottomLevelASToLocalSpace = XMMatrixInverse(nullptr, mTransform);
    };

    UINT offset = 0;
    // Analytic primitives.
    {
        using namespace AnalyticPrimitive;
        
        for (Primitive& p : analyticalObjects) {
            //SetTransformForAABB(offset + p.getType(), mScale15, mRotation);
            if (!instancing) {
                if (p.getType() != AnalyticPrimitive::Ellipsoid) {
                    if (p.getType() == AnalyticPrimitive::AABB) {
                        SetTransformForAABB(offset + p.getType(), mScale15, mRotation);
                    }
                    else if (p.getType() == AnalyticPrimitive::Hyperboloid) {
                        SetTransformForAABB(offset + p.getType(), mScale15, hypRot);

                    }
                    else {
                        SetTransformForAABB(offset + p.getType(), mIdentity, mRotation);
                    }
                    //  offset++; 
                }
                else {
                    SetTransformForAABB(offset + p.getType(), mIdentity, mRotation);
                }
            }
            else {
                SetTransformForAABB(offset + p.getType(), mScale15, mRotation);
            }
        }
       
        offset += AnalyticPrimitive::Count + 1;
    }


    {
        using namespace SignedDistancePrimitive;

        if (quatJulia) {
            SetTransformForAABB(offset + SignedDistancePrimitive::QuaternionJulia, mScale3, hypRot);
        }

        if (bloobs) {
            SetTransformForAABB(offset + SignedDistancePrimitive::MetaBalls, mScale15, mRotation);

        }
        offset += SignedDistancePrimitive::Count;

    }
    
    {

        if (CSG) {
            using namespace CSGPrimitive;
            SetTransformForAABB(offset + CSGPrimitive::CSG, mScale15, cup);
        }
    }

}

void Scene::BuildMeshes(std::unique_ptr<DX::DeviceResources>& m_deviceResources) {
    auto device = m_deviceResources->GetD3DDevice();
   
    uint32_t i = 0;
    uint32_t offset = 0;

    for (Geometry& g : meshes) {
        std::vector<Vertex> vertexBuffer = g.getVertices();
        std::vector<uint32_t> indexBuffer = g.getIndices();
        //totalVertices.resize(g.getVertices().size() + offset);
        offset = totalVertices.size();

        totalVertices.insert(totalVertices.end(), vertexBuffer.begin(), vertexBuffer.end());
        if (i > 0) {
            g.updateIndicesOffset(offset);
        }
        totalIndices.insert(totalIndices.end(), indexBuffer.begin(), indexBuffer.end());
        i++;
    }

    UINT size = static_cast<UINT>(totalVertices.size() * sizeof(Vertex));
    UINT i_size = static_cast<UINT>(totalIndices.size()) * sizeof(UINT32);
    AllocateUploadBuffer(device, totalIndices.data(), i_size, &m_indexBuffer.resource);
    AllocateUploadBuffer(device, totalVertices.data(), size, &m_vertexBuffer.resource);
    // Vertex buffer is passed to the shader along with index buffer as a descriptor range.
    /*(UINT descriptorIndexIB = CreateBufferSRV(m_deviceResources, &m_indexBuffer, totalIndices.size(), 0);
    UINT descriptorIndexVB = CreateBufferSRV(&m_vertexBuffer, totalVertices.size(), sizeof(totalVertices[0]));
    ThrowIfFalse(descriptorIndexVB == descriptorIndexIB + 1, L"Vertex Buffer descriptor index must follow that of Vertex_Index Buffer descriptor index");*/
}


void Scene::BuildProceduralGeometryAABBs(std::unique_ptr<DX::DeviceResources> &m_deviceResources)
{
    auto device = m_deviceResources->GetD3DDevice();

    // Set up AABBs on a grid.
    {
        XMINT3 aabbGrid = XMINT3(1, 1, 1);
        const XMFLOAT3 basePosition =
        {
            -(aabbGrid.x * c_aabbWidth + (aabbGrid.x - 1) * c_aabbDistance) / 2.0f,
            -(aabbGrid.y * c_aabbWidth + (aabbGrid.y - 1) * c_aabbDistance) / 2.0f,
            -(aabbGrid.z * c_aabbWidth + (aabbGrid.z - 1) * c_aabbDistance) / 2.0f,
        };

        XMFLOAT3 stride = XMFLOAT3(c_aabbWidth + c_aabbDistance, c_aabbWidth + c_aabbDistance, c_aabbWidth + c_aabbDistance);
        auto InitializeAABB = [&](auto& offsetIndex, auto& size)
        {
            return D3D12_RAYTRACING_AABB{
                basePosition.x + offsetIndex.x * stride.x,
                basePosition.y + offsetIndex.y * stride.y,
                basePosition.z + offsetIndex.z * stride.z,
                basePosition.x + offsetIndex.x * stride.x + size.x,
                basePosition.y + offsetIndex.y * stride.y + size.y,
                basePosition.z + offsetIndex.z * stride.z + size.z,
            };
        };
        //resize to number of actual geometry in the bottom level acceleration structure
        m_aabbs.resize(IntersectionShaderType::TotalPrimitiveCount);
        UINT offset = 0;

        // Analytic primitives.
        {
            using namespace AnalyticPrimitive;
            for (Primitive& p : analyticalObjects) {
                //m_aabbs[offset + Spheres] = InitializeAABB(XMFLOAT3(rand() % 2, 1, rand() % 2), XMFLOAT3(6, 6, 6));
                //offset++;
                m_aabbs[p.getType()] = InitializeAABB(p.getIndex(), p.getSize());

               // m_aabbs[offset + p.getType()] = InitializeAABB(p.getIndex(), p.getSize());
             
            }
            offset += AnalyticPrimitive::Count + 1;
        }
        

        {

         
        {

                using namespace SignedDistancePrimitive;

            if (quatJulia) {

                m_aabbs[offset + QuaternionJulia] = InitializeAABB(XMFLOAT3(-1 ,-0.1, -1), XMFLOAT3(9, 9, 9));
            }
            if (bloobs) {

                m_aabbs[offset + SignedDistancePrimitive::MetaBalls] = InitializeAABB(XMFLOAT3(1.5f, -0.3, 0), XMFLOAT3(6, 6, 6));
            }

            }
            offset += SignedDistancePrimitive::Count;

        }

        {
            if (CSG) {
                using namespace CSGPrimitive;
                m_aabbs[offset + CSGPrimitive::CSG] = InitializeAABB(XMFLOAT3(-0.4f, -0.7, 0), XMFLOAT3(9, 9, 9));
            }

        }
        AllocateUploadBuffer(device, m_aabbs.data(), m_aabbs.size() * sizeof(m_aabbs[0]), &m_aabbBuffer.resource);
    }
}

void Scene::sceneUpdates(float animationTime, std::unique_ptr<DX::DeviceResources>& m_deviceResources, ConstantBuffer<RasterSceneCB> &m_rasterConstantBuffer, bool m_animateLights, float time)
{
    camera->Update(m_sceneCB, m_rasterConstantBuffer);
    UpdateAABBPrimitiveAttributes(animationTime, m_animateLights, m_deviceResources);
    m_sceneCB->frameNumber = frameCount;
    frameCount += 1;
    if (m_animateLights)
    {
        float secondsToRotateAround = 8.0f;
        float angleToRotateBy = -360.0f * (time / secondsToRotateAround);
        XMMATRIX rotate = XMMatrixRotationY(XMConvertToRadians(angleToRotateBy));
        const XMVECTOR& prevLightPosition = m_sceneCB->lightSphere;
        //
        m_sceneCB->lightSphere = XMVector3Transform(prevLightPosition, rotate);

      //  float elapsedTime = static_cast<float>(m_timer.GetElapsedSeconds());
        //_rasterConstantBuffer->mvp = scene->GetMVP();
         //upload compute constants
        // m_computeConstantBuffer->cameraDirection = scene->getCameraDirection();
         //m_computeConstantBuffer->cameraPos = scene->getCameraPosition();
         //m_computeConstantBuffer->projectionToWorld = XMMatrixInverse(nullptr, scene->GetMVP());
         //memcpy


            m_sceneCB->elapsedTime += time;
    }


    srand((unsigned int)time);
   
    m_sceneCB->rand1 = rand()%10000 ;
    m_sceneCB->rand2 = rand();
    m_sceneCB->rand3 = rand();
    m_sceneCB->rand4 = rand();
    if (camera->moving) {
        m_sceneCB->accumulatedFrames = 0;
        camera->moving = false;
    }
    else {
        m_sceneCB->accumulatedFrames += 1;
    }
   // LPCSTR s = LPCSTR(m_sceneCB->accumulatedFrames);
   // OutputDebugStringA(s);
 //   m_sceneCB->lightPosition = camera->getPosition();
}



void Scene::CreateCSGTree(std::unique_ptr<DX::DeviceResources>  &m_deviceResources) {
    auto device = m_deviceResources->GetD3DDevice();
    auto frameCount = m_deviceResources->GetBackBufferCount();
    csgTree.Create(device, 7, frameCount, L"CSG Tree");
}

void Scene::CreateAABBPrimitiveAttributesBuffers(std::unique_ptr<DX::DeviceResources>& m_deviceResources)
{
    auto device = m_deviceResources->GetD3DDevice();
    auto frameCount = m_deviceResources->GetBackBufferCount();
    m_aabbPrimitiveAttributeBuffer.Create(device, IntersectionShaderType::TotalPrimitiveCount, frameCount, L"AABB primitive attributes");
}


void Scene::releaseResources() {
   m_sceneCB.Release();
   csgTree.Release();
   m_aabbPrimitiveAttributeBuffer.Release();
   m_indexBuffer.resource.Reset();
   m_vertexBuffer.resource.Reset();
   m_aabbBuffer.resource.Reset();
}

XMVECTOR Scene::getCameraDirection() {
    return camera->getDirection();
}

XMVECTOR Scene::getCameraPosition() {
    return camera->getPosition();
}
ConstantBuffer<SceneConstantBuffer>* Scene::getSceneBuffer()
{
    return &m_sceneCB;
}

D3DBuffer* Scene::getAABB()
{
    return &m_aabbBuffer;
}

StructuredBuffer<PrimitiveInstancePerFrameBuffer>* Scene::getPrimitiveAttributes() {
    return &m_aabbPrimitiveAttributeBuffer;
}

StructuredBuffer<CSGNode>* Scene::getCSGTree()
{
    return &csgTree;
}


void Scene::CreateSpheres() {
    float X = 1.0f;
    for (int i = 0; i < 3; i++) {
        float x = static_cast <float> (rand()) / (static_cast <float> (RAND_MAX / X));
        float y = static_cast <float> (rand()) / (static_cast <float> (RAND_MAX / X));
        float z = static_cast <float> (rand()) / (static_cast <float> (RAND_MAX / X));
        PrimitiveConstantBuffer sphere_b = { XMFLOAT4(0.9 , 0.1, 0.1, 0), 0, 0, 1, 0.4f, 50, 1 };

        Primitive sphere(AnalyticPrimitive::Enum::Spheres, sphere_b, XMFLOAT3(0, 0, 0), XMFLOAT3(6
            , 6
            , 6
        ));
        analyticalObjects.push_back(sphere);
    }
}

void Scene::CreateGeometry() {
    // XMFLOAT4(0.8, 0.64, 0.12, 0)


    PrimitiveConstantBuffer sphere_b = { XMFLOAT4(0.8, 0.0, 0, 0), 0.0f, 1.7f, 0, 1.0f, 50, 1 };
    PrimitiveConstantBuffer aa = { XMFLOAT4(0.1, 0.9f, 0.0f, 0), 1, 2.4f, 1, 0.4f, 50, 1 };
    PrimitiveConstantBuffer c = { XMFLOAT4(0.8f, 0.8f, 0.8f, 0), 0, 0, 1, 0.4f, 50, 1 };

    Primitive sphere(AnalyticPrimitive::Enum::Spheres, sphere_b, XMFLOAT3(0, -0.45f,0), XMFLOAT3(6, 6, 6));
    PrimitiveConstantBuffer hy_b = { XMFLOAT4(0.01, 0.8, 0.8, 0), 0, 1.7f, 0, 1.0f, 50, 1 };
    PrimitiveConstantBuffer ellipse_b = { XMFLOAT4(0, 0.3, 0.7, 0), 0, 0.0f, 0.3f, 1.0f, 50, 1 };
    PrimitiveConstantBuffer AABB_b = { XMFLOAT4(0.8, 0.8, 0.8, 0), 1, 0, 0, 1.0f, 50, 1 };
    PrimitiveConstantBuffer cylin_b = { XMFLOAT4(0.8, 0.64, 0.12, 0), 1, 0, 0.2f, 1.0f, 50, 1 };
    PrimitiveConstantBuffer parab_b = { XMFLOAT4(0.4f, 0.0f, 0.6f, 0), 0.0F, 0.0f, 0.0f, 1.0f, 50, 1 };
    PrimitiveConstantBuffer cone_b = { XMFLOAT4(0.1, 0.7f, 0.1, 0), 0, 1.7f, 0, 1.0f, 50, 1 };
    PrimitiveConstantBuffer CSG = { XMFLOAT4(0.0, 0.0, 0.0, 0), 2, 1, 1, 0.4f, 50, 1 };
    PrimitiveConstantBuffer pointLightSphere = { XMFLOAT4(1, 1, 1, 0) , 0, 0, 1, 0.4f, 50, 1 };

    PrimitiveConstantBuffer e = { ChromiumReflectance, 0, 0, 1, 0.4f, 50, 1 };
    //Primitive ellipsoid(AnalyticPrimitive::Enum::Ellipsoid, ellipse_b, XMFLOAT3(-3.0f, 0.0f, 1.0f), XMFLOAT3(9, 9, 9));

    Primitive hyperboloid(AnalyticPrimitive::Enum::Hyperboloid, hy_b, XMFLOAT3(0.0f, -0.1, 0.0f), XMFLOAT3(9, 9, 9));
    Primitive ellipsoid(AnalyticPrimitive::Enum::Ellipsoid, ellipse_b, XMFLOAT3(0.3f, -0.8f, 0.1f ), XMFLOAT3(9, 9, 9));
    Primitive specialAABB(AnalyticPrimitive::AABB, AABB_b, XMFLOAT3(-20, -20, -20 ), XMFLOAT3(200, 200, 200));
    Primitive Sphere(AnalyticPrimitive::Sphere, sphere_b, XMFLOAT3(0.2f, -0.1f, 0.0f), XMFLOAT3(3, 3, 3));
    Primitive pointLight(AnalyticPrimitive::PointLightSphere, pointLightSphere, XMFLOAT3(10, 18, -0.0f), XMFLOAT3(6, 6, 6));

    Primitive Cone(AnalyticPrimitive::Cone, cone_b, XMFLOAT3(-1.0f, 0.0f, 2.5f), XMFLOAT3(6, 6, 6));
    Primitive Square(AnalyticPrimitive::AABB, c, XMFLOAT3(1.0f, 0.0f, 0.0f), XMFLOAT3(3, 3, 3));
     //Primitive Square(AnalyticPrimitive::AABB, aa, XMFLOAT3(2.0f, 0.0f, -4.0f), XMFLOAT3(10, 10, 10));

    Primitive Paraboloid(AnalyticPrimitive::Paraboloid, parab_b, XMFLOAT3(1, -0.6f, -1.0f), XMFLOAT3(6, 6, 6));
    Primitive Cylinder(AnalyticPrimitive::Cylinder, cylin_b, XMFLOAT3(0.0f, -0.16, -0.0f), XMFLOAT3(10, 2, 10));
    Primitive difference(AnalyticPrimitive::Enum::CSG_Difference, CSG, XMFLOAT3(0.0f, 0.0f, -2.0f), XMFLOAT3(2, 2, 2));
    Primitive csg_union(AnalyticPrimitive::Enum::CSG_Union, CSG, XMFLOAT3(0.0f, 0.0f, 0.0f), XMFLOAT3(6, 6, 6));
    Primitive intersection(AnalyticPrimitive::Enum::CSG_Intersection, CSG, XMFLOAT3(0, 0.0f, 0), XMFLOAT3(10, 10, 10));
    Primitive plane(AnalyticPrimitive::Plane, parab_b, XMFLOAT3(-1.0f, 0.0f, 0.0f), XMFLOAT3(6, 6, 6));
    Primitive plane2(AnalyticPrimitive::Plane, AABB_b, XMFLOAT3(1, 3.0f, 0.0f), XMFLOAT3(6, 6, 6));
    Primitive cornellInner(AnalyticPrimitive::CornellBack, cone_b, XMFLOAT3(0, 0, 0.0f), XMFLOAT3(3, 3, 3));
    Primitive otherBox(AnalyticPrimitive::AABB, ellipse_b, XMFLOAT3(4.0f, 0, 3.0f), XMFLOAT3(3, 3, 3));
   // analyticalObjects = {};
    analyticalObjects = { sphere };

}

//this should be contained in the Descriptor Heap object

