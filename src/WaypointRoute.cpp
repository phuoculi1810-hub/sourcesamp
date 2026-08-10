// ============================================================================
// WaypointRoute.cpp
// Bản build-được, mô phỏng lại logic "Drive/Walk to Waypoint" từ inacty.asi
// (GTA San Andreas), dựa trên phân tích pseudocode IDA Pro (sub_1000D920,
// sub_1000E390, sub_1000EB60, sub_1000E5E0).
//
// ĐIỀU KHIỂN (thay cho menu gốc — vì không xác định được framework menu gốc):
//   F5 = Add Waypoint tại vị trí hiện tại của player
//   F6 = Bật / Tắt Route (Start Route / Stop Route)
//   F7 = Clear Waypoints (xoá hết + dừng route)
//
// LƯU Ý:
//  - Đây là bản viết lại THEO HÀNH VI đã phân tích, không phải source gốc.
//  - Phần AssignDriveTowardsTask dùng CTaskComplexControlCarMoveWithFollowRoute
//    /AutoPilot đơn giản. Đây là điểm CẦN BẠN TỰ TEST TRONG GAME kỹ nhất,
//    vì đây là chỗ suy luận nhiều nhất từ pseudoc (MEMORY[0x42F870] chưa
//    verify được là hàm gốc nào). Nếu xe không lái đúng như mong đợi, đây
//    là chỗ đầu tiên cần chỉnh.
// ============================================================================

#include <plugin.h>
#include <CPed.h>
#include <CVehicle.h>
#include <CPools.h>
#include <CWorld.h>
#include <CTimer.h>
#include <CPad.h>
#include <cmath>
#include <vector>

using namespace plugin;

// ----------------------------------------------------------------------------
// Cấu trúc 1 waypoint (16 byte, đúng theo stride đã thấy trong pseudocode)
// ----------------------------------------------------------------------------
struct Waypoint
{
    bool  visited;
    float x;
    float y;
    float z;
};

// ----------------------------------------------------------------------------
// State toàn cục
// ----------------------------------------------------------------------------
static bool                  g_bRouteActive = false;
static std::vector<Waypoint> g_waypoints;
static size_t                g_currentIndex = 0;

static constexpr float DIST_THRESHOLD_VEHICLE = 5.0f;
static constexpr float DIST_THRESHOLD_ONFOOT   = 0.5f;
static constexpr float CRUISE_SPEED            = 20.0f; // theo hằng số "+20.0" thấy ở sub_1000D920

// ----------------------------------------------------------------------------
// Phát âm thanh báo hiệu khi tới waypoint (giữ đơn giản: dùng frontend beep
// có sẵn của game thay vì mò đúng Sound ID 930 gốc — an toàn hơn khi build lần đầu)
// ----------------------------------------------------------------------------
static void PlayWaypointReachedSound()
{
    // plugin-sdk cung cấp sẵn hàm phát sound frontend, ví dụ:
    // AudioEngine::ReportFrontendAudioEvent(FRONTEND_AUDIO_HUD, 1.0f, 0);
    // Tạm thời để trống — không bắt buộc để logic hoạt động đúng.
}

// ----------------------------------------------------------------------------
// Gán lệnh lái xe tới toạ độ đích — dùng AutoPilot đơn giản (ổn định, không
// cần biết đúng offset gốc 0x42F870). Cách này KHÁC bản gốc nhưng đạt cùng
// mục đích: xe tự lái hướng về waypoint.
// ----------------------------------------------------------------------------
static void AssignDriveTowardsTask(CVehicle* vehicle, float destX, float destY, float destZ)
{
    if (!vehicle)
        return;

    // Auto-pilot đơn giản: đặt điểm đến và tốc độ hành trình.
    // (Tên field có thể khác tuỳ version plugin-sdk — nếu compile lỗi ở đây,
    //  mở CAutomobile.h / CVehicle.h trong plugin-sdk để đối chiếu tên đúng.)
    vehicle->AutoPilot.m_nCarMission        = MISSION_CRUISE;
    vehicle->AutoPilot.m_nCruiseSpeed       = static_cast<uint8_t>(CRUISE_SPEED);
    vehicle->AutoPilot.m_vecDestinationCoors = CVector(destX, destY, destZ);
}

// Dừng lệnh lái tự động khi Stop Route / Clear Waypoints
static void StopDriveTask()
{
    CPed* player = FindPlayerPed();
    if (player && player->m_pVehicle)
    {
        player->m_pVehicle->AutoPilot.m_nCarMission = MISSION_NONE;
    }
}

// ----------------------------------------------------------------------------
// Logic tick chính — tương ứng sub_1000E390, chạy mỗi frame.
// ----------------------------------------------------------------------------
static void Tick_DriveToWaypoint()
{
    if (!g_bRouteActive)
        return;

    if (g_waypoints.size() < 2)
        return; // cần tối thiểu 2 waypoint (đúng như pseudocode: if (v2 >= 2))

    // Hết mảng -> quay vòng lại từ đầu (loop route)
    if (g_currentIndex >= g_waypoints.size())
    {
        for (auto& wp : g_waypoints)
            wp.visited = false;
        g_currentIndex = 0;
    }

    Waypoint& target = g_waypoints[g_currentIndex];
    if (target.visited)
        return;

    CPed* player = FindPlayerPed();
    if (!player)
        return;

    float curX, curY;
    float threshold;
    CVehicle* vehicle = player->m_pVehicle;

    if (vehicle)
    {
        curX = vehicle->GetPosition().x;
        curY = vehicle->GetPosition().y;
        threshold = DIST_THRESHOLD_VEHICLE;

        AssignDriveTowardsTask(vehicle, target.x, target.y, target.z);
    }
    else
    {
        curX = player->GetPosition().x;
        curY = player->GetPosition().y;
        threshold = DIST_THRESHOLD_ONFOOT;
    }

    float deltaX   = curX - target.x;
    float deltaY   = curY - target.y;
    float distance = std::sqrt(deltaX * deltaX + deltaY * deltaY);

    if (distance < threshold)
    {
        PlayWaypointReachedSound();
        target.visited = true;
        g_currentIndex++;
    }
}

// ----------------------------------------------------------------------------
// Hành động điều khiển qua hotkey
// ----------------------------------------------------------------------------
static void Action_AddWaypoint()
{
    CPed* player = FindPlayerPed();
    if (!player)
        return;

    Waypoint wp;
    wp.visited = false;
    wp.x = player->GetPosition().x;
    wp.y = player->GetPosition().y;
    wp.z = player->GetPosition().z;

    g_waypoints.push_back(wp);
}

static void Action_ToggleRoute()
{
    g_bRouteActive = !g_bRouteActive;
    if (!g_bRouteActive)
        StopDriveTask();
}

static void Action_ClearWaypoints()
{
    StopDriveTask();
    g_bRouteActive = false;
    g_currentIndex = 0;
    g_waypoints.clear();
}

// ----------------------------------------------------------------------------
// Xử lý phím bấm — dùng edge detection đơn giản để tránh bấm giữ bị lặp lại
// liên tục nhiều lần trong 1 giây.
// ----------------------------------------------------------------------------
static bool g_prevF5 = false, g_prevF6 = false, g_prevF7 = false;

static void CheckHotkeys()
{
    bool curF5 = (GetAsyncKeyState(VK_F5) & 0x8000) != 0;
    bool curF6 = (GetAsyncKeyState(VK_F6) & 0x8000) != 0;
    bool curF7 = (GetAsyncKeyState(VK_F7) & 0x8000) != 0;

    if (curF5 && !g_prevF5) Action_AddWaypoint();
    if (curF6 && !g_prevF6) Action_ToggleRoute();
    if (curF7 && !g_prevF7) Action_ClearWaypoints();

    g_prevF5 = curF5;
    g_prevF6 = curF6;
    g_prevF7 = curF7;
}

// ----------------------------------------------------------------------------
// Hook chính chạy mỗi frame — plugin-sdk gọi hàm này qua Events::gameProcessEvent
// ----------------------------------------------------------------------------
static void OnGameProcess()
{
    CheckHotkeys();
    Tick_DriveToWaypoint();
}

// ----------------------------------------------------------------------------
// Điểm khởi tạo plugin — plugin-sdk tự động gọi khi .asi được nạp vào game.
// Đây là phần bắt buộc phải có để build ra .asi hoạt động được.
// ----------------------------------------------------------------------------
class WaypointRoutePlugin
{
public:
    WaypointRoutePlugin()
    {
        Events::gameProcessEvent += OnGameProcess;
    }
};

static WaypointRoutePlugin gWaypointRoutePlugin;
