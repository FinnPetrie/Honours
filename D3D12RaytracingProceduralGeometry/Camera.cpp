#include "stdafx.h"
#include "Camera.h"
using namespace DirectX;


Camera::Camera(float aspectRatio) : aspectRatio(aspectRatio) {
    m_eye = { 0.0f, 5.3f, -10.0f, 0.0f };
    //m_at = { 0.0f, 0.0f, 0.0f, 1.0f };
    m_front = { 0.0f, 0.0f, 1.0f, 0.0f };

    m_at = XMVectorAdd(m_front, m_eye);
    m_right = { 1.0f, 0.0f, 0.0f, 0.0f };

    m_direction = XMVector4Normalize(m_at - m_eye);
    m_up = XMVector3Normalize(XMVector3Cross(m_direction, m_right));
}

void Camera::Update(ConstantBuffer<SceneConstantBuffer> &scene)
{
    m_at = XMVectorAdd(m_eye, m_front);

    m_direction = XMVector4Normalize(m_at - m_eye);
    // m_up = XMVector3Normalize(XMVector3Cross(m_direction, m_right));
    //speed = 0.5f;
    //auto frameIndex = m_deviceResources->GetCurrentFrameIndex();
    //m_eye = XMVector3Transform(m_eye, XMMatrixTranslationFromVector(speed * trans));

    scene->cameraPosition = m_eye;

    float fovAngleY = 45.0f;
    XMMATRIX view = XMMatrixLookAtLH(m_eye, m_at, m_up);
    XMMATRIX proj = XMMatrixPerspectiveFovLH(XMConvertToRadians(fovAngleY), aspectRatio, 0.01f, 125.0f);
    XMMATRIX viewProj = view * proj;
    scene->projectionToWorld = XMMatrixInverse(nullptr, viewProj);
}

void Camera::OnKeyDown(UINT8 key) {
    XMVECTOR perp_Pos = XMVector3Normalize(XMVector3Cross(m_front, m_up));

    switch (key) {
    case 'A':
        m_eye = XMVector3Transform(m_eye, XMMatrixTranslationFromVector(speed * perp_Pos));
        //::cout << m_eye << std::endl;
        break;
    case 'S':
        m_eye = XMVector3Transform(m_eye, XMMatrixTranslationFromVector(-speed * m_front));
        break;
    case 'W':

        m_eye = XMVector3Transform(m_eye, XMMatrixTranslationFromVector(speed * m_front));
        break;
    case 'D':
        m_eye = XMVector3Transform(m_eye, XMMatrixTranslationFromVector(-speed * perp_Pos));
        break;
    case 'I':
        speed += 1.0f;
        break;
    case 'O':
        speed -= 1.0f;
        if (speed < 0) {
            speed = 0.1;
        }
        break;
    }
}

void Camera::OnMouseMove(float dx, float dy) {

    if (firstMouse) // initially set to true
    {
        lastX = dx;
        lastY = dy;
        firstMouse = false;
    }
    // float xoffset = float(x) - lastX;
    // float yoffset = lastY - float(y);
    lastX = dx;
    lastY = dy;
    float xoffset = -(dx);
    float yoffset = -(dy);
    float sensitivity = 0.05f;
    xoffset *= sensitivity;
    yoffset *= sensitivity;

   // std::cout << "Yaw before " << yaw << std::endl;

    yaw += xoffset;
    //std::cout << "Yaw after " << yaw << std::endl;
    pitch += yoffset;
    //std::cout << "Pitch before " << pitch << std::endl;
    // pitch += yoffset;
    //std::cout << "Pitch after " << pitch << std::endl;

    if (pitch > 89.0f) {
        pitch = 89.0f;
    }

    if (pitch < -89.0f) {
        pitch = -89.0f;
    }
    float pitchRad = XMConvertToRadians(pitch);
    float yawRad = XMConvertToRadians(yaw);
    XMVECTOR new_Front = { cos(pitchRad) * cos(yawRad), sin(pitchRad), cos(pitchRad) * sin(yawRad) };
    m_front = XMVector3Normalize(new_Front);

}