#if defined _vector_show_included
 #endinput
#endif
#define _vector_show_included

#define SPRITE_MODEL_PATH "materials/sprites/laserbeam.vmt"

ConVar
	g_hVectorShowEnable;

int sprite;

enum {
	COLOR_RED,
	COLOR_GREEN,
	COLOR_BLUE,
	COLOR_YELLOW,
	COLOR_PINK,
	COLOR_WHITE
};

// 地图开始时加载粒子材质
void vectorShowOnMapStart() {
	g_hVectorShowEnable = CreateConVar("vec_show_enable", "1", "是否启用 Vector Show 显示效果", FCVAR_NOTIFY, true, 0.0, true, 1.0);

	sprite = PrecacheModel(SPRITE_MODEL_PATH);
}

/**
* 以 start 坐标为起始位置, end 坐标为中止位置, 发射射线
* @param colorType 颜色类型
* @param start 起始位置
* @param end 终止位置
* @param length 起始位置到中止位置的长度缩放 0.0 表示不缩放
* @return void
**/
stock void ShowPos(int colorType, float start[3], float end[3], float life = 10.0, float length = 0.0, float width1 = 1.0, float width2 = 11.0) {
	if (!g_hVectorShowEnable.BoolValue) {
		return;
	}

	float copy[3];
	if (length > 0.0) {
		SubtractVectors(end, start, copy);
		NormalizeVector(copy, copy);
		ScaleVector(copy, length);
		AddVectors(start, copy, copy);
	} else {
		CopyVector(end, copy);
	}
	ShowLaser(colorType, start, copy, life, width1, width2);
}

stock void ShowDir(int colorType, float pos[3], float dir[3], float life = 10.0, float length = 200.0, float width1 = 1.0, float width2 = 11.0) {
	if (!g_hVectorShowEnable.BoolValue) {
		return;
	}
	
	float pos2[3];
	CopyVector(dir, pos2);
	NormalizeVector(pos2, pos2);
	ScaleVector(pos2, length);
	AddVectors(pos, pos2, pos2);
	ShowLaser(colorType, pos, pos2, life, width1, width2);
}

/**
* 以某点作为起始位置, 以一个角度发射射线, 显示角度
* @param colorType 颜色类型
* @param pos 起始位置
* @param angle 需要显示的角度
* @return void
**/
stock void ShowAngle(int colorType, float pos[3], float angle[3], float life = 10.0, float length = 200.0, float width1 = 1.0, float width2 = 11.0) {
	if (!g_hVectorShowEnable.BoolValue) {
		return;
	}

	float pos2[3];
	GetAngleVectors(angle, pos2, NULL_VECTOR, NULL_VECTOR);
	NormalizeVector(pos2, pos2);
	ScaleVector(pos2, length);
	AddVectors(pos, pos2, pos2);
	ShowLaser(colorType, pos, pos2, life, width1, width2);
}

stock void CopyVector(float source[3], float target[3]) {
	target[0] = source[0];
	target[1] = source[1];
	target[2] = source[2];
}

/**
* 从起始位置坐标到终点位置坐标射出射线
* @param colorType 颜色类型
* @param start 起始位置坐标
* @param end 终点位置坐标
* @return void
**/
stock void ShowLaser(int colorType, float start[3], float end[3], float life = 10.0, float width1 = 1.0, float width2 = 11.0) {
	if (!g_hVectorShowEnable.BoolValue) {
		return;
	}

	int c[4];
	// 透明度设置
	c[3] = 255;

	switch (colorType) {
		case COLOR_RED: {
			c[0] = 255; c[1] = 0; c[2] = 0;
		}
		case COLOR_GREEN: {
			c[0] = 0; c[1] = 255; c[2] = 0;
		}
		case COLOR_BLUE: {
			c[0] = 0; c[1] = 0; c[2] = 255;
		}
		case COLOR_YELLOW: {
			c[0] = 255; c[1] = 255; c[2] = 0;
		}
		case COLOR_PINK: {
			c[0] = 255; c[1] = 20; c[2] = 147;
		}
		case COLOR_WHITE: {
			c[0] = 255; c[1] = 255; c[2] = 255;
		}
	}

	TE_SetupBeamPoints(start, end, sprite, 0, 0, 0, life, width1, width2, 1, 0.0, c, 0);
	TE_SendToAll();
}