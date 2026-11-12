-- =========================================================================
-- 📌 CẤU HÌNH HỆ THỐNG & THỜI GIAN CHỜ MỞ RƯƠNG
-- =========================================================================
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local VirtualInputManager = game:GetService("VirtualInputManager") -- Dịch vụ giả lập phím
local LocalPlayer = Players.LocalPlayer

local TIME_WAIT = 3                 -- Thời gian chờ load game ban đầu
local WAIT_TIME_AT_POINT = 6          -- Thời gian dừng lại mở rương tại mỗi điểm (giây)
local MOVE_SPEED = 16               -- Tốc độ di chuyển ngang
local HOVER_OFFSET = 18             -- Độ cao bay lên khi di chuyển giữa các điểm (studs)
local ASCENT_SPEED = 4              -- Tốc độ cất cánh và hạ độ cao từ từ

local FINAL_TARGET = Vector3.new(-575.23, 8.09, -3.57) -- Tọa độ kết thúc hành trình

-- =========================================================================
-- 📋 DANH SÁCH TỌA ĐỘ TUẦN TỰ
-- =========================================================================
local Waypoints = {
    -- 1. KHO SÚNG
    {Position = Vector3.new(-245.26, 8.36, 51.79)},
    {Position = Vector3.new(-245.27, 8.36, 56.20)},
    {Position = Vector3.new(-242.49, 8.60, 63.26)},
    {Position = Vector3.new(-237.67, 8.60, 57.57)},
    {Position = Vector3.new(-236.84, 8.60, 51.39)},

    -- 2. BÀN LÀM VIỆC
    {Position = Vector3.new(-231.93, 8.45, 30.38)},
    {Position = Vector3.new(-236.72, 8.45, 30.41)},
    {Position = Vector3.new(-246.03, 8.45, 32.15)},
    {Position = Vector3.new(-251.87, 8.45, 31.40)},

    -- 3. TỰ DO
    --{Position = Vector3.new(-276.69, 9.40, 45.06)},
    --{Position = Vector3.new(-276.09, 9.40, 50.39)},
    --{Position = Vector3.new(-276.61, 9.40, 58.60)},

    -- 4. SHOP SÚNG
    {Position = Vector3.new(21.61, 7.98, -30.75)},
    {Position = Vector3.new(16.52, 7.98, -32.67)},
    {Position = Vector3.new(10.83, 7.98, -35.08)},
    {Position = Vector3.new(10.83, 7.98, -38.87)},
    {Position = Vector3.new(2.23, 7.90, -33.04)},
    {Position = Vector3.new(-2.26, 7.90, -33.34)},

    -- 5. BÊN TRONG SHOP SÚNG
    {Position = Vector3.new(9.45, 7.90, -49.25)},
    {Position = Vector3.new(14.94, 7.90, -49.26)},
    {Position = Vector3.new(22.98, 7.90, -42.58)},

    -- 6. TỰ DO SHOP SÚNG
    {Position = Vector3.new(1.36, 7.90, -49.43)},
    {Position = Vector3.new(-2.85, 7.90, -43.21)},
}

-- =========================================================================
-- ⚡ HÀM HỖ TRỢ: GIẢ LẬP PHÍM BẤM
-- =========================================================================
local function NhanPhim(keycode)
    VirtualInputManager:SendKeyEvent(true, keycode, false, game)
    task.wait(0.1) -- Giữ phím trong khoảnh khắc nhỏ
    VirtualInputManager:SendKeyEvent(false, keycode, false, game)
end

-- =========================================================================
-- 🚀 TIẾN TRÌNH CHÍNH
-- =========================================================================
task.spawn(function()
    print("📌 Chờ load game...")
    task.wait(TIME_WAIT)

    local char = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
    local root = char:WaitForChild("HumanoidRootPart")
    local hum = char:WaitForChild("Humanoid")

    for _, v in ipairs(root:GetChildren()) do
        if v.Name == "AutoFarmVelocity" then v:Destroy() end
    end

    local bv = Instance.new("BodyVelocity")
    bv.Name = "AutoFarmVelocity"
    bv.MaxForce = Vector3.new(0, math.huge, 0)
    bv.Velocity = Vector3.new(0, 0, 0)
    bv.Parent = root

    hum.PlatformStand = true

    local function DiChuyenDen(targetPos, customY)
        local isMoving = true
        local conn
        
        conn = RunService.RenderStepped:Connect(function(dt)
            if not char or not char.Parent or hum.Health <= 0 then
                if bv then bv:Destroy() end
                if conn then conn:Disconnect() end
                return
            end

            local currentPos = root.Position
            local targetY = customY or currentPos.Y
            
            local targetXZ = Vector3.new(targetPos.X, currentPos.Y, targetPos.Z)
            local distXZ = (targetXZ - Vector3.new(currentPos.X, currentPos.Y, currentPos.Z)).Magnitude
            
            local nextY = currentPos.Y
            if math.abs(currentPos.Y - targetY) > 0.1 then
                if currentPos.Y < targetY then
                    nextY = math.min(currentPos.Y + (ASCENT_SPEED * dt), targetY)
                else
                    nextY = math.max(currentPos.Y - (ASCENT_SPEED * dt), targetY)
                end
            end

            if distXZ <= 1.5 and math.abs(nextY - targetY) <= 0.1 then
                conn:Disconnect()
                isMoving = false
                return
            end

            local moveDir = (Vector3.new(targetPos.X, 0, targetPos.Z) - Vector3.new(currentPos.X, 0, currentPos.Z))
            if moveDir.Magnitude > 0 then
                moveDir = moveDir.Unit
            end

            local step = math.min(MOVE_SPEED * dt, distXZ)
            local nextXZPos = Vector3.new(currentPos.X, 0, currentPos.Z) + (moveDir * step)
            if distXZ <= 1.5 then
                nextXZPos = Vector3.new(targetPos.X, 0, targetPos.Z)
            end

            local finalPos = Vector3.new(nextXZPos.X, nextY, nextXZPos.Z)
            root.CFrame = CFrame.new(finalPos, finalPos + (moveDir ~= Vector3.zero and moveDir or root.CFrame.LookVector))
        end)

        while isMoving do
            task.wait()
        end
        root.AssemblyLinearVelocity = Vector3.zero
    end

    -- 🛫 1. NGAY KHI CHẠY SCRIPT: Cất cánh bay lên 18 studs đầu tiên
    print("🚀 Bắt đầu cất cánh bay lên độ cao an toàn...")
    local initialTakeoffY = root.Position.Y + HOVER_OFFSET
    DiChuyenDen(Vector3.new(root.Position.X, initialTakeoffY, root.Position.Z), initialTakeoffY)

    print("🚀 Bắt đầu hành trình tự động quét tọa độ!")

    -- 🔄 2. LẶP QUA TỪNG TỌA ĐỘ TRONG DANH SÁCH
    for index, waypoint in ipairs(Waypoints) do
        local target = waypoint.Position
        print(string.format("📍 [Điểm %d] Đang bay ngang tới tọa độ XZ mục tiêu...", index))

        -- Bước A: Bay ngang trên không đến vị trí XZ của điểm tiếp theo
        local currentFlightY = root.Position.Y
        DiChuyenDen(Vector3.new(target.X, currentFlightY, target.Z), currentFlightY)

        -- Bước B: Từ từ hạ xuống đúng độ cao Y của điểm đến
        print(string.format("⬇️ [Điểm %d] Hạ độ cao xuống Y = %.2f...", index, target.Y))
        DiChuyenDen(target, target.Y)

        -- Bước C: Mở rương bằng cách nhấn phím F
        print(string.format("📦 [Điểm %d] Đã tới nơi. Nhấn phím [F] để mở rương...", index))
        NhanPhim(Enum.KeyCode.F)

        print(string.format("⏳ Đang chờ %d giây...", WAIT_TIME_AT_POINT))
        task.wait(WAIT_TIME_AT_POINT)

        -- Bước D: Đợi hết thời gian -> Nhấn phím Tab để tắt
        print(string.format("⌨️ [Điểm %d] Hết thời gian chờ. Nhấn phím [Tab] để đóng...", index))
        NhanPhim(Enum.KeyCode.Tab)
        task.wait(0.2) -- Nghỉ nhẹ sau khi gửi lệnh tắt giao diện

        -- Bước E: Bay lên cao 18 studs ngay tại chỗ rồi mới sang điểm tiếp theo
        print(string.format("🛫 [Điểm %d] Bay lên cao %d studs trước khi sang điểm kế tiếp...", index, HOVER_OFFSET))
        local safeFlyY = root.Position.Y + HOVER_OFFSET
        DiChuyenDen(Vector3.new(root.Position.X, safeFlyY, root.Position.Z), safeFlyY)
    end

    -- 🏁 3. HOÀN THÀNH HẾT -> BAY VỀ ĐÍCH CUỐI CÙNG
    print("🏁 Đã hoàn thành tất cả các điểm! Đang bay về tọa độ cuối cùng...")
    local safeFlyYFinal = root.Position.Y + HOVER_OFFSET
    DiChuyenDen(Vector3.new(FINAL_TARGET.X, safeFlyYFinal, FINAL_TARGET.Z), safeFlyYFinal)
    DiChuyenDen(FINAL_TARGET, FINAL_TARGET.Y)

    print("✅ Hoàn thành toàn bộ quy trình script!")
end)
