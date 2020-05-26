#pragma once
#include "stdafx.h"
#include "RaytracingSceneDefines.h"
class Camera
{
private:

	//camera spatial variables
	XMVECTOR m_eye;
	XMVECTOR m_front;
	XMVECTOR m_up;
	XMVECTOR m_at;
	XMVECTOR m_direction;
	XMVECTOR m_right;

	//camera input variables
	UINT lastX = 400;
	UINT lastY = 300;
	float pitch = 0.0f;
	float yaw = -90.0f;
	bool firstMouse = true;
	float speed = 0.2f;

	float aspectRatio;


public:

	virtual void OnKeyDown(UINT8 key);
	virtual void OnMouseMove(float x, float y);

	Camera(float aspectRatio);

	void Update(ConstantBuffer<SceneConstantBuffer> &scene);

};
