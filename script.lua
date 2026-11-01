-- ============================================
-- BYPASS INTERNO (PROTEÇÃO AUTOMÁTICA)
-- ============================================

_G.IsExploited = nil
_G.CheatDetected = nil
_G.ScriptLoaded = nil
getgenv().BypassActive = true

task.wait(0.2)

game:GetService("RunService").Heartbeat:Connect(function()
    if _G.IsExploited then _G.IsExploited = nil end
    if _G.CheatDetected then _G.CheatDetected = nil end
end)

-- ============================================
-- SEU SCRIPT ORIGINAL COMEÇA AQUI
-- ============================================

print("[BYPASS] Proteção ativada!")
-- Arise StudyHub: arquivo completo, com Auto Execute por teleporte.
assert(game.GameId == 7074860883, "Este instalador e para Arise")
assert(type(writefile) == "function" and type(readfile) == "function", "Executor sem arquivos locais")
if type(makefolder) == "function" then pcall(makefolder, "AriseStudyHub") end
local hubSource = [====[
-- Arise: selecao de mobs pelo estado do servidor e ataque pelo modulo nativo.
assert(game.GameId == 7074860883, "Este arquivo e para Masmorra de Arise")
if not game:IsLoaded() then game.Loaded:Wait() end
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Input = game:GetService("UserInputService")
local Http = game:GetService("HttpService")
local player = Players.LocalPlayer
while not player do task.wait() player = Players.LocalPlayer end
local shared = game:GetService("ReplicatedStorage"):WaitForChild("SharedModules")
local storage = shared.Parent
local general = require(storage:WaitForChild("BridgeNet2")).ReferenceBridge("GENERAL_EVENT")
local weapons = require(shared:WaitForChild("WeaponsModule"))
local enemyState = require(shared:WaitForChild("Enemies"):WaitForChild("EnemyLocal"))
assert(type(weapons.Click) == "function", "Ataque nativo indisponivel")
local env = getgenv()
local previous = env.__AriseStudyHub
if previous and type(previous.destroy) == "function" then previous.destroy() end
local state = {enabled = false, target = nil, map = nil, kills = 0, attacks = 0}
local pumpkin = {enabled = false, collected = 0}
local alive, busy, generation = true, false, 0
local connections = {}
local cleanupCallbacks = {}
local autoExecute = false
local trialCards = {enabled = false,
    buffs = {"OnePunch", "TimeOnKill", "TimeExt", "LessEnemy", "RichKing", "GiantSlayer", "DualDmg", "DmgUp", "ShdUp", "TimeBank", "GlassCannon"},
    curses = {"Inflation", "ArmoredBoss", "BuffEnemy", "Weakness", "HLHaunted", "Horde", "HLBloodMoon", "TimeLeak", "ShortClock", "HLClockHex", "SealRange", "SealShadow", "SealWeapon"}}
-- TRIAL CARDS POLICY: penalties first; buff priority breaks ties.
local function normalizeCardOrder(order, catalog)
    local result, seen = {}, {}
    for _, id in ipairs(type(order) == "table" and order or {}) do
        if catalog[id] and not seen[id] then table.insert(result, id) seen[id] = true end
    end
    local missing = {}
    for id in pairs(catalog) do if not seen[id] then table.insert(missing, id) end end
    table.sort(missing)
    for _, id in ipairs(missing) do table.insert(result, id) end
    return result
end
local function chooseTrialCard(choices, buffs, curses)
    local selected, bestCurse, bestBuff
    for index, choice in ipairs(choices) do
        if type(choice) == "table" and type(choice.Buff) == "table" then
            local curseRank = choice.Curse and (table.find(curses, choice.Curse.Id) or (#curses + 1)) or 0
            local buffRank = table.find(buffs, choice.Buff.Id) or (#buffs + 1)
            if not selected or curseRank < bestCurse or (curseRank == bestCurse and buffRank < bestBuff) then
                selected, bestCurse, bestBuff = index, curseRank, buffRank
            end
        end
    end
    return selected
end
-- END TRIAL CARDS POLICY
local uiState = {tab = "Dungeon", x = 0.5, y = 0.5, ox = 0, oy = 0, minimizeKey = "RightControl", hideTotal = false}
-- DUNGEON POLICY
local dungeonModes = {
    {id = "portal", name = "Dungeon Portal", event = "DungeonAction", kind = "party"},
    {id = "key", name = "Dungeon com chave", event = "DungeonKeyAction", kind = "key"},
    {id = "infernal", name = "Castelo Infernal", event = "CastleAction", kind = "castle"},
    {id = "heavenly", name = "Castelo Celestial", event = "CastleAction", kind = "castle", castle = "Heavenly"},
    {id = "infcastle", name = "Castelo Infinito", event = "InfiniteCastleAction", kind = "wave"},
    {id = "desert", name = "Deserto Infinito", event = "InfiniteModeAction", kind = "wave"},
    {id = "labyrinth", name = "Labirinto Infinito", event = "InfiniteLabyrinthAction", kind = "wave"},
    {id = "bossrush", name = "Boss Rush", event = "BossRushAction", kind = "difficulty"},
    {id = "trial", name = "Time Trial", event = "TimeTrialAction", kind = "difficulty"},
    {id = "ranktest", name = "Teste de Rank", event = "DungeonAction", kind = "test"},
    {id = "hospital", name = "Ancient Hospital", event = "HLRaidAction", kind = "hospital"},
}
local dungeon = {enabled = false, mode = "infernal", difficulty = "Easy", checkpoint = 0, key = ""}
local function dungeonPlan(mode, config, context)
    if context.inside then return nil, "Partida em andamento. Auto Dungeon permanece ligado." end
    if not context.open then return nil, "Aguardando a abertura do modo..." end
    if mode.kind == "castle" then
        return {Event = mode.event, Action = "Join", Castle = mode.castle, Check = config.checkpoint > 0, Floor = config.checkpoint > 0 and tostring(config.checkpoint) or nil}, "Entrando no castelo..."
    end
    if mode.kind == "test" or mode.kind == "hospital" then
        return {Event = mode.event, Action = mode.kind == "test" and "TestEnter" or "Join"}, "Solicitando entrada..."
    end
    local room = context.room
    if not room then
        if mode.kind == "key" and config.key == "" then return nil, "Selecione uma chave para entrar." end
        return {Event = mode.event, Action = mode.kind == "key" and "SelectKey" or "Create", Key = mode.kind == "key" and config.key or nil}, "Criando grupo..."
    end
    if room.Leader ~= context.userId then return nil, "Aguardando o lider iniciar o grupo." end
    if room.Locked then return nil, "Grupo iniciando. Aguardando teleporte..." end
    return {Event = mode.event, Action = "Start", Dungeon = room.Leader, Diff = mode.kind == "difficulty" and config.difficulty or nil, Check = mode.kind == "wave" and config.checkpoint > 0 and tostring(config.checkpoint) or nil}, "Iniciando a partida..."
end
local function castleCheckpoints(best)
    local options = {{id = 0, name = "Inicio  /  Andar 1"}}
    best = tonumber(best)
    if not best or best ~= best then return options end
    for floor = 10, math.min(math.floor(best), 1000) do
        if floor % 10 == 0 or floor % 25 == 0 then
            table.insert(options, {id = floor, name = "Andar " .. floor .. (floor % 25 == 0 and "  /  Boss" or "  /  Checkpoint")})
        end
    end
    return options
end
-- END DUNGEON POLICY
-- MISC POLICY: mesmos valores e indicadores usados pela interface nativa.
local miscModes = {
    {id = "castle", name = "Castelo Infernal", flag = "IsCastle", progress = "CurrentRoom", unit = "andar", event = "CastleAction", attribute = "InfernalSpeed", values = {1, 4, 8}, requests = {1, 2, 4}, everyone = true},
    {id = "heavenly", name = "Castelo Celestial", flag = "IsHeavenCastle", progress = "CurrentRoom", unit = "andar", event = "CastleAction", attribute = "InfernalSpeed", values = {1, 4, 8}, requests = {1, 2, 4}, everyone = true},
    {id = "desert", name = "Deserto Infinito", flag = "InInfinite", progress = "CurrentWave", unit = "wave", event = "InfiniteModeAction", attribute = "DesertSpeed", values = {1, 3, 6}, requests = {1, 2, 3}},
    {id = "infcastle", name = "Castelo Infinito", flag = "InInfiniteC", progress = "CurrentWave", unit = "wave", event = "InfiniteCastleAction", attribute = "DesertSpeed", values = {1, 3, 6}, requests = {1, 2, 3}},
    {id = "labyrinth", name = "Labirinto Infinito", flag = "InInfiniteL", progress = "CurrentWave", unit = "wave", event = "InfiniteLabyrinthAction", attribute = "DesertSpeed", values = {1, 3, 6}, requests = {1, 2, 3}},
}
local function miscDecision(config, progress)
    if type(progress) ~= "number" or progress ~= progress or progress < 1 or progress == math.huge then return nil end
    if config.exitEnabled and config.exitAt > 0 and progress >= config.exitAt then return "leave" end
    if not config.speedEnabled then return nil end
    local selected, threshold = 1, -1
    for index = 2, 3 do
        local at = config["at" .. index]
        if progress >= at and at >= threshold then selected, threshold = index, at end
    end
    return "speed", selected
end
-- END MISC POLICY
local function insideDungeon()
    if storage:GetAttribute("Dungeon") == true or storage:GetAttribute("InRush") == true or storage:GetAttribute("InTimeTrial") == true or storage:GetAttribute("HLRaid") == true then return true end
    for _, mode in ipairs(miscModes) do if storage:GetAttribute(mode.flag) == true then return true end end
    return false
end
local function farmEnabled()
    return state.enabled or (dungeon.enabled and insideDungeon())
end
local misc = {}
for _, mode in ipairs(miscModes) do
    misc[mode.id] = {speedEnabled = false, at2 = 50, at3 = 100, exitEnabled = false, exitAt = 0}
end
local profilePath = "AriseStudyHub/" .. player.UserId .. ".json"
local ok, saved = pcall(function() return Http:JSONDecode(readfile(profilePath)) end)
if ok and type(saved) == "table" and saved.userId == player.UserId then
    state.enabled = saved.enabled == true
    pumpkin.enabled = saved.pumpkinEnabled == true
    autoExecute = saved.autoExecute == true
    if type(saved.trialCards) == "table" then
        trialCards.enabled = saved.trialCards.enabled == true
        if type(saved.trialCards.buffs) == "table" then trialCards.buffs = saved.trialCards.buffs end
        if type(saved.trialCards.curses) == "table" then trialCards.curses = saved.trialCards.curses end
    end
    if type(saved.ui) == "table" then
        uiState.hideTotal = saved.ui.hideTotal == true
        for _, key in ipairs({"x", "y", "ox", "oy", "miniX", "miniY", "miniOX", "miniOY"}) do
            local number = tonumber(saved.ui[key])
            if number and number == number and math.abs(number) <= 10000 then uiState[key] = number end
        end
        if saved.ui.tab == "Farm" or saved.ui.tab == "Dungeon" or saved.ui.tab == "Misc" then uiState.tab = saved.ui.tab end
        if type(saved.ui.minimizeKey) == "string" then
            local valid, key = pcall(function() return Enum.KeyCode[saved.ui.minimizeKey] end)
            if valid and key and key ~= Enum.KeyCode.Unknown and key ~= Enum.KeyCode.Escape then uiState.minimizeKey = key.Name end
        end
    end
    if type(saved.dungeon) == "table" then
        local value = saved.dungeon
        dungeon.enabled = value.enabled == true
        dungeon.repeatGems = value.repeatGems == true
        if type(value.gemResetPending) == "string" then dungeon.gemResetPending = value.gemResetPending end
        for _, mode in ipairs(dungeonModes) do if value.mode == mode.id then dungeon.mode = value.mode end end
        if type(value.difficulty) == "string" then dungeon.difficulty = value.difficulty end
        if type(value.key) == "string" then dungeon.key = value.key end
        local number = tonumber(value.checkpoint)
        if number and number == number and number >= 0 and number <= 1000000 then dungeon.checkpoint = math.floor(number) end
    end
    for _, mode in ipairs(miscModes) do
        local value = type(saved.misc) == "table" and saved.misc[mode.id]
        if type(value) == "table" then
            local config = misc[mode.id]
            config.speedEnabled, config.exitEnabled = value.speedEnabled == true, value.exitEnabled == true
            for _, key in ipairs({"at2", "at3", "exitAt"}) do
                local number = tonumber(value[key])
                if number and number == number and number >= 0 and number <= 1000000 then config[key] = math.min(mode.everyone and 1000 or 1000000, math.floor(number)) end
            end
        end
    end
end
local function save()
    if type(writefile) ~= "function" then return false, "Executor sem arquivos locais" end
    return pcall(function()
        if type(makefolder) == "function" then pcall(makefolder, "AriseStudyHub") end
        writefile(profilePath, Http:JSONEncode({userId = player.UserId, enabled = state.enabled, misc = misc, dungeon = dungeon,
            autoExecute = autoExecute, ui = uiState, pumpkinEnabled = pumpkin.enabled, trialCards = trialCards}))
    end)
end
local function connect(signal, callback)
    local c = signal:Connect(callback)
    connections[#connections + 1] = c
    return c
end
local function enemyFolder()
    local main = workspace:FindFirstChild("__Main")
    local enemies = main and main:FindFirstChild("__Enemies")
    return enemies and enemies:FindFirstChild("Server")
end
local function living(enemy, folder)
    if not enemy or not folder or enemy.Parent ~= folder or not enemy:IsA("BasePart")
        or not enemy:GetAttribute("Id") then return false end
    if enemyState.Dead(enemy) then return false end
    if enemy:GetAttribute("Dead") == nil and enemyState.Get(enemy.Name) == nil then return false end
    local hp = enemyState.HP(enemy)
    if hp == nil then return false end
    local number = tonumber(hp)
    if number then return number == number and number > 0 end
    -- O jogo representa vidas muito grandes como strings, alem do limite de double.
    return type(hp) == "string" and hp:match("^%d") ~= nil and hp ~= "0"
end
local function nearest(folder, position, map)
    local selected, distance
    if not folder then return nil end
    for _, enemy in ipairs(folder:GetChildren()) do
        if living(enemy, folder) and (not map or tostring(enemy:GetAttribute("MapId")) == map) then
            local value = (enemy.Position - position).Magnitude
            if not distance or value < distance then selected, distance = enemy, value end
        end
    end
    return selected
end
-- DUNGEON SEARCH: visit generated rooms to load distant enemy markers.
local function dungeonSearchPoints(world, currentRoom)
    local rooms, points = {}, {}
    if not world or type(currentRoom) ~= "number" then return points end
    for _, room in ipairs(world:GetChildren()) do
        local index = tonumber(room.Name:match("^Room_(%d+)$"))
        if index and index <= currentRoom then table.insert(rooms, {model = room, index = index}) end
    end
    table.sort(rooms, function(a, b)
        if a.index == b.index then return false end
        if a.index == currentRoom then return true end
        if b.index == currentRoom then return false end
        return a.index > b.index
    end)
    for _, item in ipairs(rooms) do
        local room = item.model
        local entrance, exit = room:FindFirstChild("Entrace"), room:FindFirstChild("Exit")
        local floor = room:GetAttribute("MinY")
        if entrance and entrance:IsA("BasePart") and exit and exit:IsA("BasePart") and type(floor) == "number" then
            for _, fraction in ipairs({0.8, 0.5, 0.2}) do
                local position = entrance.Position:Lerp(exit.Position, fraction)
                table.insert(points, Vector3.new(position.X, floor + 4, position.Z))
            end
        end
    end
    return points
end
-- END DUNGEON SEARCH
local function rootPart()
    local char = player.Character
    local root = char and (char:FindFirstChild("HumanoidRootPart") or char.PrimaryPart)
    local human = char and char:FindFirstChildOfClass("Humanoid")
    return root and human and human.Health > 0 and root or nil
end
local function make(class, props, parent)
    local x = Instance.new(class)
    for k, v in pairs(props) do x[k] = v end
    x.Parent = parent
    return x
end
local colors = {bg = Color3.fromRGB(7, 18, 30), card = Color3.fromRGB(11, 28, 44), edge = Color3.fromRGB(38, 75, 101), text = Color3.fromRGB(236, 245, 255), muted = Color3.fromRGB(154, 182, 210), accent = Color3.fromRGB(0, 216, 236)}
local gui = make("ScreenGui", {Name = "AriseStudyHub", ResetOnSpawn = false, DisplayOrder = 10000, ZIndexBehavior = Enum.ZIndexBehavior.Sibling}, player:WaitForChild("PlayerGui"))
local window = make("Frame", {Name = "HubWindow", Size = UDim2.fromOffset(500, 820), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(uiState.x, uiState.ox, uiState.y, uiState.oy), BackgroundColor3 = colors.bg, BorderSizePixel = 0, ClipsDescendants = true}, gui)
make("UICorner", {CornerRadius = UDim.new(0, 18)}, window)
make("UIStroke", {Color = colors.accent, Transparency = 0.35, Thickness = 1}, window)
make("UIGradient", {Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(190, 218, 245)), Rotation = 90}, window)
local scale = make("UIScale", {Scale = 1}, window)
local miniLogo = make("TextButton", {Name = "MinimizedLogo", Text = "S", Size = UDim2.fromOffset(44, 44), AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = colors.bg, BackgroundTransparency = 0.87, TextColor3 = colors.accent, TextTransparency = 0.4, Font = Enum.Font.GothamBold, TextSize = 25, BorderSizePixel = 0, Visible = false}, gui)
make("UICorner", {CornerRadius = UDim.new(0, 8)}, miniLogo)
make("UIStroke", {Color = colors.edge, Transparency = 0.8, Thickness = 1}, miniLogo)
local miniDragged = false
local function savePositions()
    uiState.x, uiState.y = window.Position.X.Scale, window.Position.Y.Scale
    uiState.ox, uiState.oy = window.Position.X.Offset, window.Position.Y.Offset
    uiState.miniX, uiState.miniY = miniLogo.Position.X.Scale, miniLogo.Position.Y.Scale
    uiState.miniOX, uiState.miniOY = miniLogo.Position.X.Offset, miniLogo.Position.Y.Offset
    return save()
end
local function availablePumpkin(model, folder, userId)
    if not folder or not model or model.Parent ~= folder or model:GetAttribute(tostring(userId)) ~= nil then return nil end
    local part = model:FindFirstChild("Main")
    local prompt = model:FindFirstChildWhichIsA("ProximityPrompt", true)
    if part and part:IsA("BasePart") and prompt and prompt.Enabled and prompt:IsDescendantOf(part) then return part, prompt end
    return nil
end
local function fit()
    local size = gui.AbsoluteSize
    if size.X <= 24 or size.Y <= 24 then return end
    local newScale = math.min(1, (size.X - 24) / 500, (size.Y - 24) / 820)
    local resized = window:GetAttribute("CanvasWidth") ~= size.X or window:GetAttribute("CanvasHeight") ~= size.Y
    scale.Scale = newScale
    if not resized then return end
    window:SetAttribute("CanvasWidth", size.X)
    window:SetAttribute("CanvasHeight", size.Y)
    local centerX = window.Position.X.Scale * size.X + window.Position.X.Offset
    local centerY = window.Position.Y.Scale * size.Y + window.Position.Y.Offset
    local halfX, halfY = 250 * newScale, 410 * newScale
    if centerX - halfX < 10 or centerX + halfX > size.X - 10 or centerY - halfY < 10 or centerY + halfY > size.Y - 10 then
        window.Position = UDim2.fromScale(0.5, 0.5)
        uiState.x, uiState.y, uiState.ox, uiState.oy = 0.5, 0.5, 0, 0
        save()
    end
end
fit()
miniLogo.Position = uiState.miniX and UDim2.new(uiState.miniX, uiState.miniOX or 0, uiState.miniY or 0.5, uiState.miniOY or 0)
    or window.Position + UDim2.fromOffset(-226 * scale.Scale, -386 * scale.Scale)
connect(RunService.RenderStepped, fit)
local function label(text, x, y, width, height, parent, size, bold)
    return make("TextLabel", {Text = text, Position = UDim2.fromOffset(x, y), Size = UDim2.new(1, -width, 0, height), BackgroundTransparency = 1, Font = bold and Enum.Font.GothamBold or Enum.Font.Gotham, TextSize = size or 14, TextColor3 = bold and colors.text or colors.muted, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Center, TextWrapped = true}, parent)
end
local logo = make("TextLabel", {Text = "S", Position = UDim2.fromOffset(20, 17), Size = UDim2.fromOffset(46, 46), BackgroundColor3 = colors.card, TextColor3 = colors.accent, Font = Enum.Font.GothamBold, TextSize = 31}, window)
make("UICorner", {CornerRadius = UDim.new(0, 12)}, logo)
make("UIStroke", {Color = colors.edge, Thickness = 1}, logo)
local title = label("STUDY HUB", 80, 12, 190, 30, window, 22, true)
title.Active = true
local dragHandle = make("TextButton", {Name = "HeaderDragHandle", Text = "", Position = UDim2.fromOffset(0, 0), Size = UDim2.new(1, -100, 0, 75), BackgroundTransparency = 1, AutoButtonColor = false, ZIndex = 3}, window)
local dragBorders = {}
for _, edge in ipairs({
    {"DragLeft", UDim2.fromOffset(0, 0), UDim2.new(0, 10, 1, 0)},
    {"DragRight", UDim2.new(1, -10, 0, 0), UDim2.new(0, 10, 1, 0)},
    {"DragTop", UDim2.fromOffset(0, 0), UDim2.new(1, 0, 0, 10)},
    {"DragBottom", UDim2.new(0, 0, 1, -10), UDim2.new(1, 0, 0, 10)},
}) do
    table.insert(dragBorders, make("TextButton", {Name = edge[1], Text = "", Position = edge[2], Size = edge[3], BackgroundTransparency = 1, AutoButtonColor = false, ZIndex = 4}, window))
end
label("A R I S E", 82, 44, 190, 18, window, 11)
do
    local badge = make("Frame", {Position = UDim2.new(1, -210, 0, 25), Size = UDim2.fromOffset(106, 28), BackgroundColor3 = colors.card, BorderSizePixel = 0}, window)
    make("UICorner", {CornerRadius = UDim.new(0, 8)}, badge)
    make("UIStroke", {Color = colors.edge}, badge)
    local dot = make("Frame", {Position = UDim2.fromOffset(10, 10), Size = UDim2.fromOffset(8, 8), BackgroundColor3 = Color3.fromRGB(35, 235, 164), BorderSizePixel = 0}, badge)
    make("UICorner", {CornerRadius = UDim.new(1, 0)}, dot)
    label("Por conta", 26, 0, 30, 28, badge, 11)
end
local minimize = make("TextButton", {Text = "−", Position = UDim2.new(1, -90, 0, 22), Size = UDim2.fromOffset(30, 30), BackgroundColor3 = colors.card, TextColor3 = colors.muted, Font = Enum.Font.GothamBold, TextSize = 18}, window)
make("UICorner", {CornerRadius = UDim.new(0, 8)}, minimize)
local close = make("TextButton", {Text = "X", Position = UDim2.new(1, -50, 0, 20), Size = UDim2.fromOffset(30, 30), BackgroundColor3 = colors.card, TextColor3 = colors.muted, Font = Enum.Font.GothamBold, TextSize = 14}, window)
make("UICorner", {CornerRadius = UDim.new(0, 8)}, close)
make("Frame", {Position = UDim2.fromOffset(20, 75), Size = UDim2.new(1, -40, 0, 1), BorderSizePixel = 0, BackgroundColor3 = colors.edge}, window)
local body = make("Frame", {Position = UDim2.fromOffset(0, 85), Size = UDim2.new(1, 0, 1, -85), BackgroundTransparency = 1}, window)
local function page(name, height)
    return make("ScrollingFrame", {Name = name, Position = UDim2.fromOffset(18, 0), Size = UDim2.new(1, -36, 1, -96), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 3, ScrollBarImageColor3 = colors.accent, CanvasSize = UDim2.fromOffset(0, height), Visible = false}, body)
end
local farmPage, dungeonPage, miscPage = page("FarmPage", 632), page("DungeonPage", 860), page("MiscPage", 850)
local function card(y, height, parent)
    local value = make("Frame", {Position = UDim2.fromOffset(2, y), Size = UDim2.new(1, -8, 0, height), BackgroundColor3 = colors.card, BorderSizePixel = 0}, parent)
    make("UICorner", {CornerRadius = UDim.new(0, 12)}, value)
    make("UIStroke", {Color = colors.edge, Thickness = 1}, value)
    make("UIGradient", {Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(175, 205, 235)), Rotation = 25}, value)
    return value
end
local function button(text, y, parent)
    local value = make("TextButton", {Text = text, Position = UDim2.fromOffset(2, y), Size = UDim2.new(1, -8, 0, 46), BackgroundColor3 = colors.card, TextColor3 = colors.text, Font = Enum.Font.GothamMedium, TextSize = 14, AutoButtonColor = true}, parent)
    make("UICorner", {CornerRadius = UDim.new(0, 10)}, value)
    make("UIStroke", {Color = colors.edge, Thickness = 1}, value)
    return value
end
local function icon(kind, x, y, size, parent)
    local images = {Dungeon = "rbxassetid://105767317646901", Clock = "rbxassetid://137504361633657"}
    if images[kind] then
        return make("ImageLabel", {Image = images[kind], Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(size, size), BackgroundTransparency = 1, ScaleType = Enum.ScaleType.Fit}, parent)
    end
    if kind == "Farm" or kind == "Replay" or kind == "Keyboard" or kind == "Hide" or kind == "Activity" then
        local drawing = make("Frame", {Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(size, size), BackgroundTransparency = 1}, parent)
        local function line(px, py, width, height, rotation)
            return make("Frame", {Position = UDim2.fromScale(px, py), Size = UDim2.fromScale(width, height), Rotation = rotation or 0,
                AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = colors.accent, BorderSizePixel = 0}, drawing)
        end
        if kind == "Farm" then
            line(0.5, 0.43, 0.1, 0.76, 43) line(0.5, 0.43, 0.1, 0.76, -43)
            line(0.27, 0.72, 0.3, 0.08, 43) line(0.73, 0.72, 0.3, 0.08, -43)
        elseif kind == "Keyboard" then
            local border = make("Frame", {Position = UDim2.fromScale(0.08, 0.22), Size = UDim2.fromScale(0.84, 0.56), BackgroundTransparency = 1}, drawing)
            make("UICorner", {CornerRadius = UDim.new(0, 3)}, border)
            make("UIStroke", {Color = colors.accent, Thickness = 2}, border)
            for row = 1, 2 do for col = 1, 4 do line(0.22 + (col - 1) * 0.18, 0.35 + (row - 1) * 0.18, 0.08, 0.07) end end
        elseif kind == "Activity" then
            for _, segment in ipairs({{0.18, 0.6, 0.25, 0.06, 0}, {0.35, 0.43, 0.06, 0.6, 20}, {0.51, 0.5, 0.06, 0.8, -20}, {0.66, 0.53, 0.06, 0.4, 25}, {0.84, 0.57, 0.22, 0.06, 0}}) do line(table.unpack(segment)) end
        else
            local ring = make("Frame", {Position = UDim2.fromScale(0.18, kind == "Hide" and 0.3 or 0.18), Size = UDim2.fromScale(0.64, kind == "Hide" and 0.4 or 0.64), BackgroundTransparency = 1}, drawing)
            make("UICorner", {CornerRadius = UDim.new(1, 0)}, ring)
            make("UIStroke", {Color = colors.accent, Thickness = 2}, ring)
            if kind == "Hide" then line(0.5, 0.5, 0.08, 0.95, 45)
            else make("TextLabel", {Text = ">", Position = UDim2.fromScale(0.48, -0.12), Size = UDim2.fromScale(0.5, 0.5), Rotation = 25,
                TextColor3 = colors.accent, TextSize = size * 0.55, Font = Enum.Font.GothamBold, BackgroundTransparency = 1}, drawing) end
        end
        return drawing
    end
    local glyphs = {Misc = "⚙", Pumpkin = "🎃", Speed = ">>", Exit = "→", Cards = "▱"}
    return make("TextLabel", {Text = glyphs[kind] or "◈", Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(size, size), BackgroundTransparency = 1, TextColor3 = colors.accent, Font = Enum.Font.GothamBold, TextSize = size - 4}, parent)
end
local function pageHeader(name, caption, kind, parent)
    icon(kind, 8, 12, 44, parent)
    label(name, 66, 4, 82, 38, parent, 27, true)
    label(caption, 66, 44, 82, 32, parent, 12)
end
local function toggleRow(name, caption, y, parent, kind)
    local row = button("", y, parent)
    row.Size = UDim2.new(1, -8, 0, 78)
    local inset = kind and 62 or 16
    if kind then icon(kind, 14, 20, 34, row) end
    label(name, inset, 10, inset + 80, 25, row, 15, true)
    label(caption, inset, 37, inset + 80, 30, row, 12).Name = "Caption"
    local indicator = make("TextLabel", {Name = "State", Text = "", Position = UDim2.new(1, -68, 0.5, -14), Size = UDim2.fromOffset(52, 28), BackgroundColor3 = colors.edge}, row)
    make("UICorner", {CornerRadius = UDim.new(1, 0)}, indicator)
    local knob = make("Frame", {Name = "Knob", Size = UDim2.fromOffset(22, 22), Position = UDim2.fromOffset(3, 3), BackgroundColor3 = colors.text, BorderSizePixel = 0}, indicator)
    make("UICorner", {CornerRadius = UDim.new(1, 0)}, knob)
    return row
end
local function toggleLook(row, enabled)
    row.State.BackgroundColor3 = enabled and colors.accent or colors.edge
    row.State.Knob.Position = UDim2.fromOffset(enabled and 27 or 3, 3)
end
local function numberField(caption, y, parent)
    local head = label(caption, 6, y, 12, 25, parent, 13)
    local field = make("TextBox", {Position = UDim2.fromOffset(2, y + 30), Size = UDim2.new(1, -8, 0, 42), BackgroundColor3 = colors.card, TextColor3 = colors.text, Font = Enum.Font.GothamMedium, TextSize = 16, ClearTextOnFocus = false}, parent)
    make("UICorner", {CornerRadius = UDim.new(0, 10)}, field)
    make("UIStroke", {Color = colors.edge, Thickness = 1}, field)
    return field, head
end
pageHeader("Farm", "Combate e coleta no mundo aberto.", "Farm", farmPage)
local toggle = toggleRow("Auto Farm Mobs", "Procura o NPC vivo mais próximo.", 90, farmPage, "Farm")
toggle.Name = "AutoFarmMobs"
toggle.Size = UDim2.new(1, -8, 0, 108)
label("Nas dungeons, o combate acompanha o Auto Dungeon.", 16, 76, 32, 24, toggle, 11)
local pumpkinToggle = toggleRow("Auto Pumpkin", "Visita as ilhas e coleta as disponíveis.", 212, farmPage, "Pumpkin")
pumpkinToggle.Name = "AutoPumpkin"
local pumpkinCard = card(304, 140, farmPage)
icon("Pumpkin", 14, 12, 30, pumpkinCard)
label("COLETA DE PUMPKINS", 58, 16, 74, 22, pumpkinCard, 12, true)
local pumpkinStatus = label("Desligado.", 16, 56, 32, 72, pumpkinCard, 13)
pumpkinStatus.Name = "PumpkinStatus"
pumpkinStatus.TextYAlignment = Enum.TextYAlignment.Top
local farmStatusCard = card(460, 156, farmPage)
icon("Activity", 12, 10, 34, farmStatusCard)
label("ATIVIDADE", 58, 16, 74, 22, farmStatusCard, 12, true)
local status = label("", 16, 54, 32, 90, farmStatusCard, 14)
status.TextYAlignment = Enum.TextYAlignment.Top
pageHeader("Dungeon", "Escolha o modo. Entrada e combate automáticos.", "Dungeon", dungeonPage)
label("MODO DE JOGO", 16, 88, 32, 22, dungeonPage, 11)
local dungeonModeButton = button("", 116, dungeonPage)
local difficultyLabel = label("DIFICULDADE", 16, 174, 32, 22, dungeonPage, 11)
local difficultyButton = button("", 202, dungeonPage)
local checkpointField, checkpointLabel = numberField("Checkpoint inicial / 0 = início", 174, dungeonPage)
local checkpointButton = button("", 204, dungeonPage)
checkpointButton.Name = "CastleCheckpoint"
local dungeonToggle = toggleRow("Auto Dungeon", "Entra e combate automaticamente.", 264, dungeonPage, "Dungeon")
dungeonToggle.Name = "AutoDungeon"
local repeatGemsToggle = toggleRow("Reply Dungeon", "Repete o portal usando gemas.", 354, dungeonPage, "Replay")
repeatGemsToggle.Name = "RepeatDungeonWithGems"
local trialPreview = card(448, 284, dungeonPage)
trialPreview.Name = "TrialCardsPreview"
icon("Cards", 12, 10, 32, trialPreview)
label("Cards da Trial", 52, 12, 190, 26, trialPreview, 16, true)
local trialCardsShortcut = button("Configurar  ›", 10, trialPreview)
trialCardsShortcut.Name = "TrialCardsShortcut"
trialCardsShortcut.Position, trialCardsShortcut.Size = UDim2.new(1, -138, 0, 10), UDim2.fromOffset(126, 32)
trialCardsShortcut.TextColor3 = colors.accent
local dungeonActivity = card(748, 114, dungeonPage)
dungeonActivity.Name = "DungeonActivity"
icon("Activity", 12, 12, 34, dungeonActivity)
label("ATIVIDADE", 58, 12, 74, 22, dungeonActivity, 11, true)
local dungeonHint = label("", 16, 874, 32, 42, dungeonPage, 11)
local dungeonStatus = label("Auto Dungeon desligado.", 58, 40, 74, 62, dungeonActivity, 13)
dungeonStatus.TextYAlignment = Enum.TextYAlignment.Top
toggleLook(repeatGemsToggle, dungeon.repeatGems == true)
connect(repeatGemsToggle.Activated, function()
    dungeon.repeatGems = not dungeon.repeatGems
    toggleLook(repeatGemsToggle, dungeon.repeatGems)
    save()
end)
local trialSettings
do
    local definitions = require(storage.Indexer.TimeTrialBuffs)
    local catalogs = {buffs = {}, curses = {}}
    for category, tiers in pairs({buffs = definitions.Buffs, curses = definitions.Curses}) do
        for tier, entries in pairs(tiers) do
            for _, entry in ipairs(entries) do
                catalogs[category][entry.Id] = {data = entry, tier = tier}
            end
        end
        trialCards[category] = normalizeCardOrder(trialCards[category], catalogs[category])
    end
    local names = {
        DamageMult = "Dano das armas", ShadowDmg = "Dano das sombras", AllDmg = "Dano de armas e sombras",
        BossDmg = "Dano contra bosses", FinalDmgMult = "Todo o dano", CritChance = "Chance critica",
        CritDmg = "Dano critico", WeaponSkillCharge = "Carga da habilidade", DamageMultOff = "Reducao de dano",
        CoinMult = "Dinheiro", RewardMult = "Recompensas", GemChance = "Chance de gemas",
        TicketChance = "Chance de tickets", TimeAdd = "Tempo", TimeOnKill = "Tempo por morte",
        TimeBank = "Aproveitamento do tempo restante", EnemyReduce = "Menos inimigos por sala",
        ExtraEnemies = "Mais inimigos por sala", EnemyHpMult = "Vida dos inimigos", BossHpMult = "Vida dos bosses",
        CandyMult = "Soul Candy",
    }
    local special = {
        GlassCannon = "+200% de dano", SealShadows = "Zera o dano das sombras",
        SealWeapon = "Zera o dano da arma", SealRange = "Sela o alcance das sombras",
        RoomTimeMult = "Tempo por sala -20%",
    }
    local penalties = {GlassCannon = "-30% de tempo por sala", HLMonarchsNight = "+50% de vida dos inimigos"}
    local function describe(entry)
        local effect = special[entry.Stat]
        if entry.Id == "HLMonarchsNight" then effect = "Todo o dano x3" end
        if not effect then
            local low = definitions.FormatValue(entry.Display, entry.Min)
            local high = definitions.FormatValue(entry.Display, entry.Max)
            effect = (names[entry.Stat] or entry.Text or entry.Stat) .. " " .. low
            if low ~= high then effect ..= " a " .. high end
        end
        return effect
    end
    trialSettings = make("Frame", {Name = "TrialCardSettings", Position = UDim2.fromOffset(16, 86), Size = UDim2.new(1, -32, 1, -180),
        BackgroundColor3 = colors.bg, BorderSizePixel = 0, Visible = false, ZIndex = 10}, window)
    make("UICorner", {CornerRadius = UDim.new(0, 14)}, trialSettings)
    make("UIStroke", {Color = colors.accent, Thickness = 1}, trialSettings)
    label("Prioridade de Cards", 16, 10, 118, 30, trialSettings, 19, true)
    local back = button("Voltar", 8, trialSettings)
    back.Position, back.Size = UDim2.new(1, -90, 0, 8), UDim2.fromOffset(78, 32)
    connect(back.Activated, function() trialSettings.Visible = false end)
    connect(trialCardsShortcut.Activated, function() trialSettings.Visible = true end)
    local auto = toggleRow("Auto Cards", "Penalidade primeiro; buff desempata.", 56, trialSettings, "Cards")
    auto.Name = "AutoTrialCards"
    toggleLook(auto, trialCards.enabled)
    local statusText = label("Aguardando a próxima seleção da Trial.", 16, 140, 32, 36, trialSettings, 12)
    statusText.Name = "TrialCardsStatus"
    local category, query = "buffs", ""
    local buffTab = button("Buffs", 186, trialSettings)
    buffTab.Size = UDim2.new(0.5, -6, 0, 40)
    local curseTab = button("Penalidades", 186, trialSettings)
    curseTab.Position = UDim2.new(0.5, 2, 0, 186)
    curseTab.Size = UDim2.new(0.5, -10, 0, 40)
    local explanation = label("", 16, 234, 32, 36, trialSettings, 12)
    local search = make("TextBox", {Name = "TrialCardSearch", PlaceholderText = "Buscar card...", Text = "", ClearTextOnFocus = false,
        Position = UDim2.fromOffset(12, 278), Size = UDim2.new(1, -24, 0, 38), BackgroundColor3 = colors.card,
        TextColor3 = colors.text, PlaceholderColor3 = colors.muted, Font = Enum.Font.Gotham, TextSize = 14}, trialSettings)
    make("UICorner", {CornerRadius = UDim.new(0, 10)}, search)
    local list = make("ScrollingFrame", {Name = "TrialCardPriorityList", Position = UDim2.fromOffset(10, 328), Size = UDim2.new(1, -20, 1, -340),
        BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 3, ScrollBarImageColor3 = colors.accent}, trialSettings)
    local previewBuff = button("Buffs", 48, trialPreview)
    previewBuff.Size = UDim2.new(0.5, -8, 0, 32)
    local previewCurse = button("Penalidades", 48, trialPreview)
    previewCurse.Position, previewCurse.Size = UDim2.new(0.5, 2, 0, 48), UDim2.new(0.5, -10, 0, 32)
    local previewNote = label("", 12, 258, 24, 20, trialPreview, 10)
    local rowConnections = {}
    local function render()
        for _, connection in ipairs(rowConnections) do connection:Disconnect() end
        table.clear(rowConnections)
        list:ClearAllChildren()
        for _, item in ipairs({{buffTab, "buffs"}, {curseTab, "curses"}, {previewBuff, "buffs"}, {previewCurse, "curses"}}) do
            item[1].BackgroundColor3 = item[2] == category and Color3.fromRGB(12, 55, 72) or colors.card
            item[1].TextColor3 = item[2] == category and colors.accent or colors.muted
        end
        for _, child in ipairs(trialPreview:GetChildren()) do if child.Name == "PreviewRow" then child:Destroy() end end
        for rank = 1, math.min(3, #trialCards[category]) do
            local entry = catalogs[category][trialCards[category][rank]].data
            local row = card(88 + (rank - 1) * 56, 50, trialPreview)
            row.Name = "PreviewRow"
            label(tostring(rank), 10, 0, 0, 50, row, 12, true).Size = UDim2.fromOffset(20, 50)
            if entry.Icon then make("ImageLabel", {Image = entry.Icon, BackgroundTransparency = 1, Position = UDim2.fromOffset(34, 7), Size = UDim2.fromOffset(36, 36)}, row) end
            label(entry.Name, 80, 3, 94, 21, row, 12, true)
            local text = describe(entry)
            if penalties[entry.Id] then text ..= " / " .. penalties[entry.Id] end
            local effect = label(text, 80, 24, 94, 22, row, 10)
            effect.TextColor3 = (category == "curses" or penalties[entry.Id]) and Color3.fromRGB(255, 130, 130) or Color3.fromRGB(125, 235, 155)
        end
        previewNote.Text = trialCards.enabled and "Auto Cards ligado · Prioridades salvas por conta" or "Auto Cards desligado · Configure para ativar"
        explanation.Text = category == "buffs" and "Do buff mais desejado para o menos desejado."
            or "Da mais aceitavel para a mais prejudicial. Escolhas obrigatorias nao sao puladas."
        local y = 0
        for rank, id in ipairs(trialCards[category]) do
            local item = catalogs[category][id]
            local entry = item.data
            if query == "" or string.find(string.lower(entry.Name .. " " .. describe(entry)), query, 1, true) then
                local row = card(y, 126, list)
                row.Name = id
                label(tostring(rank), 8, 8, 16, 20, row, 12, true).Size = UDim2.fromOffset(26, 20)
                if entry.Icon then
                    make("ImageLabel", {Name = "OriginalIcon", Image = entry.Icon, BackgroundTransparency = 1,
                        Position = UDim2.fromOffset(10, 38), Size = UDim2.fromOffset(44, 44)}, row)
                end
                label(entry.Name, 62, 6, 150, 25, row, 14, true)
                local effect = label(describe(entry), 62, 32, 130, 42, row, 12)
                effect.TextColor3 = category == "curses" and Color3.fromRGB(255, 115, 115) or Color3.fromRGB(125, 235, 155)
                local note = penalties[id] or entry.PenaltyText
                local extra = label(note or item.tier, 62, 78, 130, 38, row, 11)
                extra.TextColor3 = note and Color3.fromRGB(255, 115, 115) or colors.muted
                for offset, direction in ipairs({-1, 1}) do
                    local arrow = make("TextButton", {Text = direction == -1 and "↑" or "↓", Position = UDim2.new(1, -44, 0, 10 + (offset - 1) * 46),
                        Size = UDim2.fromOffset(34, 38), BackgroundColor3 = colors.edge, TextColor3 = colors.text,
                        Font = Enum.Font.GothamBold, TextSize = 20}, row)
                    local destination = rank + direction
                    arrow.Active = destination >= 1 and destination <= #trialCards[category]
                    arrow.TextTransparency = arrow.Active and 0 or 0.7
                    table.insert(rowConnections, arrow.Activated:Connect(function()
                        local order = trialCards[category]
                        if destination < 1 or destination > #order then return end
                        order[rank], order[destination] = order[destination], order[rank]
                        save() render()
                    end))
                end
                y += 134
            end
        end
        list.CanvasSize = UDim2.fromOffset(0, y)
    end
    connect(buffTab.Activated, function() category = "buffs" list.CanvasPosition = Vector2.zero render() end)
    connect(curseTab.Activated, function() category = "curses" list.CanvasPosition = Vector2.zero render() end)
    connect(previewBuff.Activated, function() category = "buffs" render() end)
    connect(previewCurse.Activated, function() category = "curses" render() end)
    connect(search:GetPropertyChangedSignal("Text"), function() query = string.lower(search.Text) list.CanvasPosition = Vector2.zero render() end)
    table.insert(cleanupCallbacks, function() for _, connection in ipairs(rowConnections) do connection:Disconnect() end end)
    render()
    local selection
    local function vote()
        if not alive or not trialCards.enabled or not selection or selection.sent
            or os.clock() >= selection.deadline or storage:GetAttribute("InTimeTrial") ~= true then return end
        local index = chooseTrialCard(selection.choices, trialCards.buffs, trialCards.curses)
        if not index then return end
        local success, problem = pcall(function() general:Fire({Event = "TimeTrialAction", Action = "SelectBuff", Index = index}) end)
        if success then
            selection.sent = true
            local choice = selection.choices[index]
            statusText.Text = "Voto enviado: " .. tostring(choice.Buff.Name or choice.Buff.Id)
                .. (choice.Curse and (" / " .. tostring(choice.Curse.Name or choice.Curse.Id)) or " / Sem maldicao")
        else statusText.Text = "Falha ao votar: " .. tostring(problem) end
    end
    connect(auto.Activated, function()
        trialCards.enabled = not trialCards.enabled
        toggleLook(auto, trialCards.enabled)
        save()
        render()
        statusText.Text = trialCards.enabled and "Aguardando a proxima selecao da Trial." or "Auto Cards desligado."
        vote()
    end)
    local subscription = require(storage.BridgeNet2).ReferenceBridge("TRIAL_EVENT"):Connect(function(packet)
        if not alive or type(packet) ~= "table" then return end
        if packet.Event == "ShowBuffSelection" then
            selection = nil
            if packet.Kind == "Restart" or type(packet.Choices) ~= "table" or type(packet.Voters) ~= "table"
                or not table.find(packet.Voters, player.UserId) then return end
            selection = {choices = packet.Choices, deadline = os.clock() + (tonumber(packet.Time) or 15)}
            vote()
        elseif packet.Event == "CloseBuffSelection" or packet.Event == "BuffChosen" then
            selection = nil
        end
    end)
    table.insert(cleanupCallbacks, function() subscription:Disconnect() end)
end
pageHeader("Misc", "Preferências e automações.", "Misc", miscPage)
local autoExecuteToggle = toggleRow("Auto Execute", "Reabre o hub após trocar de servidor.", 90, miscPage, "Replay")
autoExecuteToggle.Name = "AutoExecute"
autoExecuteToggle.Size = UDim2.new(1, -8, 0, 108)
local autoExecuteStatus = label("Continua até fechar o Roblox.", 16, 76, 32, 24, autoExecuteToggle, 11)
local keybindButton = button("", 210, miscPage)
keybindButton.Name = "MinimizeKeybind"
keybindButton.Size = UDim2.new(1, -8, 0, 72)
icon("Keyboard", 14, 20, 32, keybindButton)
label("Minimizar / Restaurar", 62, 8, 200, 25, keybindButton, 14, true)
label("Clique para escolher outra tecla.", 62, 36, 184, 25, keybindButton, 11)
local keybindValue = label("", 0, 0, 0, 30, keybindButton, 12, true)
keybindValue.Position, keybindValue.Size, keybindValue.TextXAlignment = UDim2.new(1, -130, 0, 20), UDim2.fromOffset(114, 30), Enum.TextXAlignment.Center
keybindValue.BackgroundColor3, keybindValue.BackgroundTransparency = colors.bg, 0
make("UICorner", {CornerRadius = UDim.new(0, 7)}, keybindValue)
make("UIStroke", {Color = colors.edge}, keybindValue)
local capturingKeybind = false
local function refreshKeybind()
    local name = uiState.minimizeKey == "RightControl" and "Ctrl direito" or uiState.minimizeKey
    keybindValue.Text = capturingKeybind and "Pressione..." or name
end
refreshKeybind()
connect(keybindButton.Activated, function()
    capturingKeybind = not capturingKeybind
    refreshKeybind()
end)
local hideTotalToggle = toggleRow("Ocultar total hub", "Ao minimizar, esconde também o ícone S.", 294, miscPage, "Hide")
hideTotalToggle.Name = "HideTotalHub"
make("Frame", {Position = UDim2.fromOffset(4, 386), Size = UDim2.new(1, -12, 0, 1), BackgroundColor3 = colors.edge, BorderSizePixel = 0}, miscPage)
icon("Dungeon", 10, 397, 28, miscPage)
label("AUTOMAÇÃO DO MODO", 54, 398, 72, 26, miscPage, 12, true)
local modeButton = button("", 436, miscPage)
local speedToggle = toggleRow("Velocidade automática", "Muda a velocidade nos andares definidos.", 494, miscPage, "Speed")
local fields, labels = {}, {}
fields.at2, labels.at2 = numberField("", 584, miscPage)
fields.at3, labels.at3 = numberField("", 584, miscPage)
for _, key in ipairs({"at2", "at3"}) do
    local x = key == "at2" and 0 or 0.5
    fields[key].Position, fields[key].Size = UDim2.new(x, 4, 0, 614), UDim2.new(0.5, -12, 0, 42)
    labels[key].Position, labels[key].Size = UDim2.new(x, 6, 0, 584), UDim2.new(0.5, -14, 0, 25)
    labels[key].TextSize = 11
end
local exitToggle = toggleRow("Saída automática", "Sai ao atingir o andar escolhido.", 672, miscPage, "Exit")
fields.exitAt, labels.exitAt = numberField("Andar de saída", 762, miscPage)
local miscStatus = label("0 = sem saída programada.", 6, 840, 12, 50, miscPage, 11)
miscPage.CanvasSize = UDim2.fromOffset(0, 900)
miscStatus.TextYAlignment = Enum.TextYAlignment.Top
local pages = {Farm = farmPage, Dungeon = dungeonPage, Misc = miscPage}
local tabs = {}
local nav = make("Frame", {Name = "BottomNavigation", Position = UDim2.new(0, 16, 1, -86), Size = UDim2.new(1, -32, 0, 64), BackgroundColor3 = colors.card, BorderSizePixel = 0}, body)
make("UICorner", {CornerRadius = UDim.new(0, 12)}, nav)
make("UIStroke", {Color = colors.edge}, nav)
local footer = label("Configuracoes salvas por conta", 20, 0, 40, 16, body, 10)
footer.Position, footer.TextXAlignment = UDim2.new(0, 20, 1, -17), Enum.TextXAlignment.Center
local minimized = false
local function setMinimized(value)
    capturingKeybind = false
    refreshKeybind()
    minimized = value
    window.Visible = not minimized
    miniLogo.Visible = minimized and not uiState.hideTotal
end
local function toggleMinimize()
    setMinimized(not minimized)
end
connect(minimize.Activated, toggleMinimize)
connect(miniLogo.Activated, function() if not miniDragged then setMinimized(false) end end)
connect(hideTotalToggle.Activated, function()
    uiState.hideTotal = not uiState.hideTotal
    toggleLook(hideTotalToggle, uiState.hideTotal)
    save()
    setMinimized(uiState.hideTotal)
end)
toggleLook(hideTotalToggle, uiState.hideTotal)
-- Sempre aparece ao iniciar; a preferencia so vale ao minimizar manualmente.
setMinimized(false)
connect(Input.InputBegan, function(input, processed)
    if input.UserInputType ~= Enum.UserInputType.Keyboard then return end
    if capturingKeybind then
        if input.KeyCode == Enum.KeyCode.Escape then
            capturingKeybind = false
        elseif input.KeyCode ~= Enum.KeyCode.Unknown then
            uiState.minimizeKey = input.KeyCode.Name
            capturingKeybind = false
            save()
        end
        refreshKeybind()
        return
    end
    if not processed and not Input:GetFocusedTextBox() and input.KeyCode.Name == uiState.minimizeKey then toggleMinimize() end
end)
local function showPage(name)
    trialSettings.Visible = false
    for key, content in pairs(pages) do
        content.Visible = key == name
        tabs[key].BackgroundColor3 = key == name and Color3.fromRGB(10, 57, 75) or colors.card
        tabs[key].TextColor3 = key == name and colors.accent or colors.muted
        tabs[key].UIStroke.Color = key == name and colors.accent or colors.edge
        tabs[key].TabLabel.TextColor3 = key == name and colors.accent or colors.muted
    end
    uiState.tab = name
    save()
end
for index, name in ipairs({"Farm", "Dungeon", "Misc"}) do
    local tab = button("", 5, nav)
    tab.Name = name .. "Tab"
    tab.Position = UDim2.new((index - 1) / 3, 5, 0, 5)
    tab.Size = UDim2.new(1 / 3, -10, 1, -10)
    icon(name, 57, 3, 25, tab)
    local caption = label(name, 0, 30, 0, 19, tab, 12, true)
    caption.Name, caption.TextXAlignment = "TabLabel", Enum.TextXAlignment.Center
    tabs[name] = tab
    connect(tab.Activated, function() showPage(name) end)
end
-- Lista pesquisavel: os modos ficam visiveis sem percorrer seletores em ciclo.
local picker = make("Frame", {Name = "ChoicePicker", Position = UDim2.fromOffset(16, 90), Size = UDim2.new(1, -32, 1, -170), BackgroundColor3 = colors.bg, BorderSizePixel = 0, Visible = false, ZIndex = 10}, window)
make("UICorner", {CornerRadius = UDim.new(0, 12)}, picker)
make("UIStroke", {Color = colors.accent, Thickness = 1}, picker)
local pickerTitle = label("Selecionar", 12, 8, 70, 28, picker, 16, true)
local pickerClose = button("Voltar", 6, picker)
pickerClose.Position, pickerClose.Size = UDim2.new(1, -78, 0, 6), UDim2.fromOffset(70, 30)
local search = make("TextBox", {PlaceholderText = "Buscar...", Text = "", ClearTextOnFocus = false, Position = UDim2.fromOffset(10, 48), Size = UDim2.new(1, -20, 0, 36), BackgroundColor3 = colors.card, TextColor3 = colors.text, Font = Enum.Font.Gotham, TextSize = 14}, picker)
make("UICorner", {CornerRadius = UDim.new(0, 8)}, search)
local choices = make("ScrollingFrame", {Position = UDim2.fromOffset(8, 96), Size = UDim2.new(1, -16, 1, -106), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 3, AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new()}, picker)
make("UIListLayout", {Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder}, choices)
local function choose(titleText, options, callback)
    for _, child in ipairs(choices:GetChildren()) do if child:IsA("TextButton") then child:Destroy() end end
    search.Text, pickerTitle.Text, picker.Visible = "", titleText, true
    choices.CanvasPosition = Vector2.zero
    for index, option in ipairs(options) do
        local item = button(option.name, 0, choices)
        item.LayoutOrder = index
        item:SetAttribute("Search", string.lower(option.name))
        connect(item.Activated, function() picker.Visible = false callback(option.id) end)
    end
end
connect(pickerClose.Activated, function() picker.Visible = false end)
connect(search:GetPropertyChangedSignal("Text"), function()
    for _, child in ipairs(choices:GetChildren()) do if child:IsA("TextButton") then child.Visible = string.find(child:GetAttribute("Search"), string.lower(search.Text), 1, true) ~= nil end end
end)
local function refresh()
    toggleLook(toggle, state.enabled)
    toggleLook(pumpkinToggle, pumpkin.enabled)
    if not farmEnabled() then status.Text = "Parado. Ative para procurar mobs vivos na area atual." end
end
local function destroy()
    if not alive then return end
    savePositions()
    alive, generation = false, generation + 1
    state.target = nil
    for _, c in ipairs(connections) do c:Disconnect() end
    for _, unsubscribe in ipairs(cleanupCallbacks) do unsubscribe() end
    gui:Destroy()
    if env.__AriseStudyHub and env.__AriseStudyHub.state == state then env.__AriseStudyHub = nil end
end
env.__AriseStudyHub = {destroy = destroy, state = state, misc = misc, dungeon = dungeon, pumpkin = pumpkin}
local selectedMode = 1
local function refreshMisc()
    local mode = miscModes[selectedMode]
    local config = misc[mode.id]
    modeButton.Text = mode.name .. "   v"
    toggleLook(autoExecuteToggle, autoExecute)
    toggleLook(speedToggle, config.speedEnabled)
    toggleLook(exitToggle, config.exitEnabled)
    labels.at2.Text = mode.values[2] .. "× a partir do " .. mode.unit
    labels.at3.Text = mode.values[3] .. "× a partir do " .. mode.unit
    labels.exitAt.Text = "Sair ao atingir o " .. mode.unit
    for key, field in pairs(fields) do field.Text = tostring(config[key]) end
end
connect(modeButton.Activated, function()
    local options = {}
    for index, mode in ipairs(miscModes) do table.insert(options, {id = index, name = mode.name}) end
    choose("Velocidades", options, function(index) selectedMode = index refreshMisc() end)
end)
connect(speedToggle.Activated, function()
    local config = misc[miscModes[selectedMode].id]
    config.speedEnabled = not config.speedEnabled
    save() refreshMisc()
end)
connect(exitToggle.Activated, function()
    local config = misc[miscModes[selectedMode].id]
    config.exitEnabled = not config.exitEnabled
    save() refreshMisc()
end)
for key, field in pairs(fields) do
    connect(field.FocusLost, function()
        local number = tonumber(field.Text)
        local mode = miscModes[selectedMode]
        local maximum = mode.everyone and 1000 or 1000000
        if number and number == number and number >= 0 and number <= maximum then misc[mode.id][key] = math.floor(number) save() end
        refreshMisc()
    end)
end
showPage(uiState.tab)
refreshMisc()
local partyClient = require(shared:WaitForChild("PartyClient"))
local clientData = require(shared:WaitForChild("ClientData"))
local nativeModes, nativeSchedule, rushDifficulties = {}, nil, {}
local nativePartyShared, nativeGameData
local nativeOK, nativeProblem = pcall(function()
    local ui = player:WaitForChild("PlayerScripts"):FindFirstChild("NewUI", true)
    assert(ui and ui:FindFirstChild("Screens"), "Interface nativa ainda nao carregou")
    local config = require(ui.Screens.Modes.Config)
    nativePartyShared = require(ui.Screens.Party.Shared)
    nativeGameData = require(ui.GameData)
    nativeSchedule = config.Status
    for _, mode in ipairs(config.MODES) do nativeModes[mode.Id] = mode end
    for _, value in ipairs(require(ui.Screens.Party.Config).RUSH_DIFFS) do
        table.insert(rushDifficulties, {id = value.Name, name = value.Name})
    end
end)
local trialDifficulties, keyChoices = {}, {}
for _, name in ipairs(require(storage.Indexer.TimeTrialInfo).Order) do table.insert(trialDifficulties, {id = name, name = name}) end
local itemsInfo = require(storage.Indexer.ItemsInfo)
local keyDungeons = require(storage.Indexer.KeyDungeons)
for name in pairs(keyDungeons) do
    local info = itemsInfo[name]
    if type(info) == "table" then table.insert(keyChoices, {id = name, name = info.Name or name}) end
end
local function setAutoExecute(enabled)
    local wasEnabled = autoExecute
    autoExecute = enabled
    local session = env.__AriseAutoSession
    if not enabled then
        local success, problem = save()
        if not success then autoExecute = wasEnabled return false, problem end
        if session and session.connection then session.connection:Disconnect() end
        env.__AriseAutoSession = nil
        return true
    end
    local success, problem = pcall(function()
        local savedOK, savedProblem = save()
        assert(savedOK, savedProblem)
        assert(type(readfile) == "function", "Executor sem arquivos locais")
        assert(type(readfile("AriseStudyHub/Hub.luau")) == "string", "Execute o instalador atualizado")
        local start = assert(loadstring(readfile("AriseStudyHub/AutoExecute.luau")))
        session = assert(start(player.UserId, false), "Executor sem continuidade por teleporte")
        assert(session.queued, session.problem or "Falha ao preparar Auto Execute")
        session.beforeTeleport = savePositions
    end)
    if not success then
        autoExecute = false
        if session and session.connection then session.connection:Disconnect() end
        env.__AriseAutoSession = nil
        save()
    end
    return success, problem
end
table.sort(keyChoices, function(a, b) return a.name < b.name end)
connect(autoExecuteToggle.Activated, function()
    local success, problem = setAutoExecute(not autoExecute)
    autoExecuteStatus.Text = success and (autoExecute and "Ativo nesta sessao. Reabre apos teleporte." or "Desligado. O hub nao reabre no proximo teleporte.") or "Nao foi possivel ativar. Use o instalador atualizado. " .. tostring(problem)
    refreshMisc()
end)
if autoExecute then
    local success, problem = setAutoExecute(true)
    autoExecuteStatus.Text = success and "Ativo nesta sessao. Reabre apos teleporte." or "Auto Execute indisponivel: " .. tostring(problem)
    refreshMisc()
end
local function dungeonMode(config)
    for _, mode in ipairs(dungeonModes) do if mode.id == (config or dungeon).mode then return mode end end
    return dungeonModes[1]
end
local function unlockedCastle(mode)
    local stat = mode.id == "heavenly" and "MaxHeavenFloor" or "MaxCastleFloor"
    local best = tonumber(clientData.Get("GeneralStats", stat)) or 0
    return castleCheckpoints(best), best
end
local function refreshDungeon()
    local mode = dungeonMode()
    toggleLook(dungeonToggle, dungeon.enabled)
    dungeonModeButton.Text = mode.name .. "   v"
    local hasDiff, hasKey = mode.kind == "difficulty", mode.kind == "key"
    difficultyLabel.Visible, difficultyButton.Visible = hasDiff or hasKey, hasDiff or hasKey
    difficultyLabel.Text = hasKey and "CHAVE / PASSE" or "DIFICULDADE"
    difficultyButton.Text = hasKey and (itemsInfo[dungeon.key] and itemsInfo[dungeon.key].Name or "Selecionar chave...") or dungeon.difficulty
    local hasCheck = mode.kind == "castle" or mode.kind == "wave"
    checkpointField.Visible, checkpointLabel.Visible = mode.kind == "wave", hasCheck
    checkpointButton.Visible = mode.kind == "castle"
    checkpointField.Text = tostring(dungeon.checkpoint)
    checkpointLabel.Text = mode.kind == "castle" and "ANDAR INICIAL  /  SOMENTE LIBERADOS" or "Checkpoint inicial  /  0 = inicio"
    checkpointButton.Text = dungeon.checkpoint == 0 and "Inicio  /  Andar 1   v" or "Andar " .. dungeon.checkpoint .. "   v"
    checkpointLabel.Position = UDim2.fromOffset(16, 174)
    checkpointField.Position, checkpointButton.Position = UDim2.fromOffset(2, 204), UDim2.fromOffset(2, 204)
    local y = (hasDiff or hasKey or hasCheck) and 264 or 176
    dungeonToggle.Position = UDim2.fromOffset(2, y)
    repeatGemsToggle.Position = UDim2.fromOffset(2, y + 90)
    repeatGemsToggle.Caption.Text = mode.id == "portal" and "Repete o portal usando gemas." or "Somente Dungeon Portal. Preferência preservada."
    trialPreview.Position = UDim2.fromOffset(2, y + 184)
    dungeonActivity.Position = UDim2.fromOffset(2, y + 484)
    dungeonHint.Position = UDim2.fromOffset(16, y + 610)
    dungeonPage.CanvasSize = UDim2.fromOffset(0, y + 664)
    dungeonHint.Text = hasKey and "Selecione uma chave que voce possui. A ativacao no pedestal dentro da instancia ainda e manual."
        or hasCheck and "Usa apenas checkpoints ja liberados. Configure velocidade e saida na aba Misc."
        or "Auto Dungeon combate automaticamente dentro da partida."
    if not dungeon.enabled then dungeonStatus.Text = "Auto Dungeon desligado." end
end
connect(checkpointButton.Activated, function()
    local mode = dungeonMode()
    if mode.kind ~= "castle" then return end
    local options, best = unlockedCastle(mode)
    choose("Andares liberados  /  " .. math.min(best, 1000), options, function(floor)
        dungeon.checkpoint = floor
        save() refreshDungeon()
    end)
end)
connect(dungeonModeButton.Activated, function()
    choose("Escolher modo", dungeonModes, function(id)
        dungeon.mode = id
        save() refreshDungeon()
    end)
end)
connect(difficultyButton.Activated, function()
    local mode = dungeonMode()
    local options = mode.kind == "key" and keyChoices or (mode.id == "trial" and trialDifficulties or rushDifficulties)
    choose(mode.kind == "key" and "Escolher chave" or "Dificuldade", options, function(id)
        if mode.kind == "key" then dungeon.key = id else dungeon.difficulty = id end
        save() refreshDungeon()
    end)
end)
local nextRequest = os.clock() + 10
local lastEntrySignature
connect(dungeonToggle.Activated, function()
    dungeon.enabled = not dungeon.enabled
    state.target, state.map, state.searchPosition = nil, nil, nil
    generation += 1
    if dungeon.enabled then nextRequest = os.clock() + 10 lastEntrySignature = nil end
    save() refreshDungeon() refresh()
end)
connect(checkpointField.FocusLost, function()
    local number = tonumber(checkpointField.Text)
    if number and number == number and number >= 0 and number <= 1000000 then dungeon.checkpoint = math.floor(number) save() end
    refreshDungeon()
end)
refreshDungeon()
task.spawn(function()
    local wasInside = false
    while alive do
        task.wait(1)
        if not alive then break end
        local inside = insideDungeon()
        if inside ~= wasInside then
            state.target, state.map = nil, nil
            generation += 1
            nextRequest = os.clock() + (inside and 0 or 10)
            lastEntrySignature = nil
            wasInside = inside
        end
        if not dungeon.enabled then continue end
        local config = dungeon
        local mode = dungeonMode(config)
        if not nativeOK then dungeonStatus.Text = "Entrada indisponivel: " .. tostring(nativeProblem) continue end
        if not inside and state.leaving then dungeonStatus.Text = "Aguardando a saida da partida..." continue end
        local nativeMode = nativeModes[mode.id]
        if not nativeMode then dungeonStatus.Text = "Esse modo nao esta disponivel no menu desta versao." continue end
        local repeatInside = mode.id == "portal" and inside and dungeon.repeatGems == true
            and storage:GetAttribute("DungeonCompleted") == true
        local portalInfo
        if mode.id == "portal" and (not inside or repeatInside) then
            portalInfo = nativePartyShared.DungeonInfos()
            local world = storage:GetAttribute("World")
            local currentWorld = world and ("World" .. tostring(world)) or storage:GetAttribute("BackWorld")
            if not portalInfo or tostring(portalInfo.World) ~= currentWorld then
                dungeonStatus.Text = "Aguardando portal do " .. currentWorld .. "..."
                continue
            end
            if nativePartyShared.DungeonCompleted() then
                if not dungeon.repeatGems then
                    dungeonStatus.Text = "Portal concluido. Aguardando o proximo; Reply Dungeon desligado."
                    continue
                end
                local portalId = tostring(portalInfo.ID)
                if dungeon.gemResetPending == portalId then
                    dungeonStatus.Text = "Reset com gemas solicitado. Aguardando confirmacao; sem repetir a cobranca."
                    continue
                end
                local schedule = nativeSchedule(nativeMode, workspace:GetServerTimeNow())
                if schedule.Open ~= true and not repeatInside then dungeonStatus.Text = "Aguardando abertura do portal para repetir." continue end
                local info = require(storage.Indexer.DungeonInfo)[portalInfo.Dungeon]
                local price = info and info.Rejoin and info.Rejoin.Gems
                if not price then dungeonStatus.Text = "Preco do reset indisponivel; nenhuma compra enviada." continue end
                if not nativeGameData.HasCurrency("Gems", price) then
                    dungeonStatus.Text = "Gemas insuficientes para repetir a dungeon."
                    continue
                end
                if os.clock() < nextRequest or not rootPart() or player.GameplayPaused then
                    dungeonStatus.Text = "Aguardando para solicitar reset com gemas..."
                    continue
                end
                -- Persist before sending: reruns must not pay again while completion is stale.
                dungeon.gemResetPending = portalId
                local persisted = save()
                if not persisted then
                    dungeon.gemResetPending = nil
                    dungeonStatus.Text = "Nao foi possivel salvar o pedido de reset; compra cancelada."
                    continue
                end
                nextRequest = os.clock() + (repeatInside and 1 or 10)
                lastEntrySignature = nil
                local paid, problem = pcall(function()
                    general:Fire({Event = "DungeonAction", Action = "BuyTicket", Type = "Gems"})
                end)
                dungeonStatus.Text = paid and "Reset com gemas solicitado. Aguardando liberacao..."
                    or "Falha no reset: " .. tostring(problem)
                continue
            end
            if dungeon.gemResetPending then dungeon.gemResetPending = nil save() end
            local room = partyClient.GetRoom(mode.event)
            if room and room.DungeonID and tostring(room.DungeonID) ~= tostring(portalInfo.ID) then
                dungeonStatus.Text = "O grupo pertence a outro portal. Saia dele para criar um novo."
                continue
            end
        end
        if mode.kind == "difficulty" then
            local valid = false
            for _, option in ipairs(mode.id == "trial" and trialDifficulties or rushDifficulties) do if option.id == config.difficulty then valid = true end end
            if not valid then dungeonStatus.Text = "Selecione uma dificuldade disponivel para esse modo." continue end
        end
        if mode.kind == "castle" and not inside then
            local valid = false
            local options = unlockedCastle(mode)
            for _, option in ipairs(options) do if option.id == config.checkpoint then valid = true end end
            if not valid then dungeonStatus.Text = "Escolha um checkpoint liberado da lista (limite 1000)." continue end
        end
        local success, problem = pcall(function()
            local schedule = nativeSchedule(nativeMode, workspace:GetServerTimeNow())
            local open = repeatInside or schedule.Open == true
            if mode.id == "portal" and not repeatInside then
                local main = workspace:FindFirstChild("__Main")
                local folder = main and main:FindFirstChild("__Dungeon")
                open = open and folder and folder:FindFirstChild("Dungeon") ~= nil
            end
            local request, message = dungeonPlan(mode, config, {inside = inside and not repeatInside, open = open, room = partyClient.GetRoom(mode.event), userId = player.UserId})
            dungeonStatus.Text = message
            local signature = request and request.Event .. ":" .. request.Action
            local ready = os.clock() >= nextRequest or (lastEntrySignature ~= nil and lastEntrySignature ~= signature)
            if request and not ready then dungeonStatus.Text = "Aguardando " .. math.ceil(nextRequest - os.clock()) .. " s para entrar..." end
            if request and ready and rootPart() and not player.GameplayPaused then
                nextRequest = os.clock() + 10
                lastEntrySignature = signature
                state.entryUntil = os.clock() + 15
                general:Fire(request)
            end
        end)
        if not success then dungeonStatus.Text = "Entrada interrompida: " .. tostring(problem) nextRequest = os.clock() + 10 lastEntrySignature = nil end
    end
end)
local speedWindowUntil = 0
connect(require(shared:WaitForChild("WaveRunClient")).SpeedShown, function(_, duration)
    speedWindowUntil = os.clock() + (tonumber(duration) or 5)
end)
task.spawn(function()
    local activeMode, lastProgress, lastSpeedAt, lastExitAt, exitAttempts = nil, nil, -math.huge, -math.huge, 0
    while alive do
        task.wait(0.5)
        if not alive then break end
        local mode
        -- Celestial tem precedencia se o jogo mantiver ambos os indicadores.
        for index = #miscModes, 1, -1 do
            if storage:GetAttribute(miscModes[index].flag) == true then mode = miscModes[index] break end
        end
        local progress = mode and tonumber(storage:GetAttribute(mode.progress))
        if mode ~= activeMode or (progress and lastProgress and progress < lastProgress) then
            activeMode, lastSpeedAt, lastExitAt, exitAttempts = mode, -math.huge, -math.huge, 0
            state.leaving, state.target, state.map = false, nil, nil
        end
        lastProgress = progress
        if not mode then miscStatus.Text = "Aguardando um dos modos configurados..." continue end
        local config = misc[mode.id]
        local action, index = miscDecision(config, progress)
        local prefix = mode.name .. " · " .. mode.unit .. " " .. tostring(progress or "?") .. "\n"
        if action == "leave" then
            state.leaving, state.target = true, nil
            miscStatus.Text = prefix .. (exitAttempts >= 3 and "Saida sem confirmacao. Confira a tela do jogo." or "Solicitando saida...")
            if exitAttempts < 3 and os.clock() - lastExitAt >= 10 then
                lastExitAt, exitAttempts = os.clock(), exitAttempts + 1
                local success, problem = pcall(function() general:Fire({Event = "LeaveDungeon"}) end)
                if not success then miscStatus.Text = prefix .. "Falha ao sair: " .. tostring(problem) end
            end
        elseif action == "speed" then
            state.leaving = false
            local desired = mode.values[index]
            if storage:GetAttribute(mode.attribute) == desired then
                miscStatus.Text = prefix .. "Velocidade: " .. desired .. "x"
            elseif not mode.everyone and storage:GetAttribute("InfiniteOwner") ~= player.Name then
                miscStatus.Text = prefix .. "A troca de velocidade exige ser o lider."
            elseif not mode.everyone and storage:GetAttribute("Intermission") ~= true and os.clock() >= speedWindowUntil then
                miscStatus.Text = prefix .. "Aguardando janela para aplicar " .. desired .. "x..."
            else
                miscStatus.Text = prefix .. "Solicitando " .. desired .. "x (depende dos requisitos do jogo)."
                if os.clock() - lastSpeedAt >= 5 then
                    lastSpeedAt = os.clock()
                    local success, problem = pcall(function() general:Fire({Event = mode.event, Action = "SpeedUp", Speed = mode.requests[index]}) end)
                    if not success then miscStatus.Text = prefix .. "Falha na velocidade: " .. tostring(problem) end
                end
            end
        else
            state.leaving = false
            miscStatus.Text = prefix .. "Velocidade automatica desligada ou aguardando progresso."
        end
    end
end)
local mapInfo = require(storage.Indexer.MapInfo)
local release = require(shared.Release)
local visitedPumpkinIslands, failedPumpkins, blockedPumpkinIslands = {}, setmetatable({}, {__mode = "k"}), {}
local nextPumpkinSweep = 0
local function releasePumpkinMovement()
    if state.pumpkinBusy then state.target, state.map = nil, nil end
    state.pumpkinBusy, pumpkin.target, pumpkin.travel = false, nil, nil
end
connect(pumpkinToggle.Activated, function()
    pumpkin.enabled = not pumpkin.enabled
    releasePumpkinMovement()
    visitedPumpkinIslands, nextPumpkinSweep = {}, 0
    save() refresh()
    if not pumpkin.enabled then pumpkinStatus.Text = "Desligado." end
end)
local extra = workspace:FindFirstChild("__Extra")
local pumpkinFolder = extra and extra:FindFirstChild("__Pumps")
if pumpkinFolder then
    connect(pumpkinFolder.ChildAdded, function() nextPumpkinSweep, visitedPumpkinIslands = 0, {} end)
end
task.spawn(function()
    local function nearestIsland(position, islands)
        local selected, distance
        for _, island in ipairs(islands) do
            local value = (island.spawn.Position - position).Magnitude
            if not distance or value < distance then selected, distance = island, value end
        end
        return selected
    end
    while alive do
        task.wait(0.5)
        if not alive then break end
        if not pumpkin.enabled then releasePumpkinMovement() continue end
        local now = os.clock()
        local prefix = "Coletadas: " .. pumpkin.collected .. "\n"
        if insideDungeon() or state.leaving or now < (state.entryUntil or 0) then
            releasePumpkinMovement()
            pumpkinStatus.Text = prefix .. "Pausado: dungeon tem prioridade."
            continue
        end
        local root = rootPart()
        if not root or player.GameplayPaused or player:GetAttribute("Mounted") or player:GetAttribute("Swimming") then
            releasePumpkinMovement()
            pumpkinStatus.Text = prefix .. "Aguardando personagem livre para coletar."
            continue
        end
        if type(fireproximityprompt) ~= "function" then
            releasePumpkinMovement()
            pumpkinStatus.Text = "Executor sem suporte a interacao de proximidade."
            continue
        end
        local currentExtra = workspace:FindFirstChild("__Extra")
        local folder = currentExtra and currentExtra:FindFirstChild("__Pumps")
        local spawns = currentExtra and currentExtra:FindFirstChild("__Spawns")
        if not folder or not spawns or #folder:GetChildren() == 0 then
            releasePumpkinMovement()
            pumpkinStatus.Text = prefix .. "Nenhuma abobora ativa neste servidor."
            continue
        end
        local success, problem = pcall(function()
            local islands = {}
            local world = tonumber(storage:GetAttribute("World"))
            for name, info in pairs(mapInfo) do
                local spawn = spawns:FindFirstChild(name)
                if type(info) == "table" and info.NoWorld ~= true and info.World == world and spawn and spawn:IsA("BasePart") and release.IsOpenFor(info) then
                    table.insert(islands, {id = name, name = info.Name or name, spawn = spawn})
                end
            end
            local here = nearestIsland(root.Position, islands)
            if not here then releasePumpkinMovement() pumpkinStatus.Text = prefix .. "Aguardando ilhas do mundo atual." return end
            local hasPass = clientData.Get("Passes", "ShadowExchange") == true
            local travel = pumpkin.travel
            if travel then
                state.pumpkinBusy = true
                if (root.Position - travel.island.spawn.Position).Magnitude <= 60 then
                    visitedPumpkinIslands[travel.island.id] = true
                    if now - travel.at >= 1.5 then pumpkin.travel = nil end
                elseif now - travel.at > 7 then
                    blockedPumpkinIslands[travel.island.id] = now + 60
                    releasePumpkinMovement()
                end
                pumpkinStatus.Text = prefix .. "Viajando para " .. travel.island.name .. "..."
                return
            end
            local target = pumpkin.target
            if target then
                if target.model:GetAttribute(tostring(player.UserId)) ~= nil then
                    pumpkin.collected += 1
                    pumpkin.target = nil
                    return
                end
                local part, prompt = availablePumpkin(target.model, folder, player.UserId)
                if not part or now - target.at > 12 then
                    failedPumpkins[target.model] = now + 60
                    pumpkin.target = nil
                    return
                end
                state.pumpkinBusy = true
                pumpkinStatus.Text = prefix .. "Coletando em " .. target.island.name .. "..."
                if (root.Position - part.Position).Magnitude <= math.min(prompt.MaxActivationDistance, 12) and now >= target.nextPrompt then
                    if target.attempts >= 3 then
                        failedPumpkins[target.model] = now + 60
                        pumpkin.target = nil
                    else
                        target.attempts, target.nextPrompt = target.attempts + 1, now + 2
                        fireproximityprompt(prompt)
                    end
                end
                return
            end
            if now < nextPumpkinSweep then
                releasePumpkinMovement()
                pumpkinStatus.Text = prefix .. "Rodada concluida. Nova busca em " .. math.ceil(nextPumpkinSweep - now) .. " s."
                return
            end
            local selected, distance
            for _, model in ipairs(folder:GetChildren()) do
                local part = availablePumpkin(model, folder, player.UserId)
                if part and now >= (failedPumpkins[model] or 0) then
                    local island = nearestIsland(part.Position, islands)
                    if island and now >= (blockedPumpkinIslands[island.id] or 0) and (hasPass or island.id == here.id) then
                        local value = (part.Position - root.Position).Magnitude
                        if not distance or value < distance then selected, distance = {model = model, island = island, at = now, attempts = 0, nextPrompt = 0}, value end
                    end
                end
            end
            local destination = selected and selected.island
            if not destination then
                table.sort(islands, function(a, b) return (a.spawn.Position - root.Position).Magnitude < (b.spawn.Position - root.Position).Magnitude end)
                visitedPumpkinIslands[here.id] = true
                if hasPass then
                    for _, island in ipairs(islands) do
                        if not visitedPumpkinIslands[island.id] and now >= (blockedPumpkinIslands[island.id] or 0) then destination = island break end
                    end
                end
            end
            if not destination then
                nextPumpkinSweep, visitedPumpkinIslands = now + 60, {}
                releasePumpkinMovement()
                pumpkinStatus.Text = prefix .. (hasPass and "Nenhuma disponivel. Aguardando nova rodada." or "Outras ilhas exigem o passe Shadow Exchange.")
                return
            end
            state.pumpkinBusy, state.target = true, nil
            if destination.id ~= here.id then
                pumpkin.travel = {island = destination, at = now}
                general:Fire({Event = "IslandTeleport", Island = destination.id})
                pumpkinStatus.Text = prefix .. "Viajando para " .. destination.name .. "..."
            else
                visitedPumpkinIslands[destination.id] = true
            end
            if selected then
                selected.at = now + (pumpkin.travel and 8 or 0)
                pumpkin.target = selected
            end
        end)
        if not success then
            releasePumpkinMovement()
            nextPumpkinSweep = now + 10
            pumpkinStatus.Text = "Coleta interrompida: " .. tostring(problem)
        end
    end
end)
connect(close.Activated, destroy)
connect(toggle.Activated, function()
    state.enabled = not state.enabled
    state.target, state.map = nil, nil
    generation += 1
    save()
    refresh()
end)
local dragging, dragInput, start, original, dragTarget
local function beginDrag(input, target)
    if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then return end
    if dragging then return end
    dragging, dragInput, start, original, dragTarget = true, input, input.Position, target.Position, target
    if target == miniLogo then miniDragged = false end
end
connect(dragHandle.InputBegan, function(input) beginDrag(input, window) end)
for _, border in ipairs(dragBorders) do connect(border.InputBegan, function(input) beginDrag(input, window) end) end
connect(miniLogo.InputBegan, function(input) beginDrag(input, miniLogo) end)
connect(Input.InputChanged, function(input)
    if dragging and (input == dragInput or (dragInput.UserInputType == Enum.UserInputType.MouseButton1 and input.UserInputType == Enum.UserInputType.MouseMovement)) then
        local delta = input.Position - start
        local size = gui.AbsoluteSize
        if size.X <= 0 or size.Y <= 0 then return end
        if delta.Magnitude > 4 and dragTarget == miniLogo then miniDragged = true end
        local half = dragTarget.AbsoluteSize / 2
        local x = math.clamp(original.X.Scale * size.X + original.X.Offset + delta.X, half.X + 8, math.max(half.X + 8, size.X - half.X - 8))
        local y = math.clamp(original.Y.Scale * size.Y + original.Y.Offset + delta.Y, half.Y + 8, math.max(half.Y + 8, size.Y - half.Y - 8))
        dragTarget.Position = UDim2.new(x / size.X, 0, y / size.Y, 0)
    end
end)
connect(Input.InputEnded, function(input)
    if dragging and input == dragInput then
        savePositions()
        dragging, dragInput, dragTarget = false, nil, nil
    end
end)
connect(gui.Destroying, destroy)
-- Um unico controlador de movimento. Nao ataca quando desligado ou sem alvo confirmado.
connect(RunService.Heartbeat, function()
    if not alive or state.leaving or player.GameplayPaused or os.clock() < (state.entryUntil or 0) then return end
    if state.pumpkinBusy then
        local root, target = rootPart(), pumpkin.target
        if root and target and not pumpkin.travel and not player:GetAttribute("Mounted") and not player:GetAttribute("Swimming") then
            local folder = workspace:FindFirstChild("__Extra") and workspace.__Extra:FindFirstChild("__Pumps")
            local part = availablePumpkin(target.model, folder, player.UserId)
            if part then root.AssemblyLinearVelocity = Vector3.zero root.CFrame = CFrame.new(part.Position + Vector3.new(0, 2, 2)) end
        end
        return
    end
    if not farmEnabled() then return end
    local root, folder = rootPart(), enemyFolder()
    if root and state.lastFarmPosition and (root.Position - state.lastFarmPosition).Magnitude > 300 then
        state.target, state.map, state.lastFarmPosition = nil, nil, root.Position
        return
    end
    if not root then return end
    if player:GetAttribute("Mounted") or player:GetAttribute("Swimming") then return end
    if not living(state.target, folder) then
        if state.searchPosition and not state.leaving and os.clock() >= (state.entryUntil or 0) then
            root.AssemblyLinearVelocity = Vector3.zero
            root.CFrame = CFrame.new(state.searchPosition)
            state.lastFarmPosition = root.Position
        end
        return
    end
    local position = state.target.Position
    root.AssemblyLinearVelocity = Vector3.zero
    root.CFrame = CFrame.lookAt(position + Vector3.new(0, 3, 4), position + Vector3.new(0, 3, 0))
    state.lastFarmPosition = root.Position
end)
task.spawn(function()
    local missingSince, searchAt, searchIndex, searchRoom = nil, 0, 0, nil
    while alive do
        task.wait(0.2)
        if not alive then break end
        if not farmEnabled() then state.searchPosition = nil missingSince = nil continue end
        if state.pumpkinBusy or os.clock() < (state.entryUntil or 0) then state.target = nil state.searchPosition = nil missingSince = nil status.Text = "Aguardando coleta ou entrada..." continue end
        if state.leaving then state.target = nil state.searchPosition = nil missingSince = nil status.Text = "Saindo da dungeon..." continue end
        local root, folder = rootPart(), enemyFolder()
        if not root then state.target = nil status.Text = "Aguardando personagem..." continue end
        if player:GetAttribute("Mounted") or player:GetAttribute("Swimming") then status.Text = "Desmonte ou saia da agua para atacar." continue end
        if insideDungeon() then state.map = nil end
        if not living(state.target, folder) then
            if state.target and (enemyState.Dead(state.target) or tonumber(enemyState.HP(state.target)) == 0) then state.kills += 1 end
            state.target = nearest(folder, root.Position, state.map)
            if state.target and not state.map and not insideDungeon() then state.map = tostring(state.target:GetAttribute("MapId")) end
        end
        local target = state.target
        if not target then
            status.Text = "Aguardando mobs vivos no mapa atual..."
            local room = tonumber(storage:GetAttribute("CurrentRoom"))
            local canSearch = storage:GetAttribute("Dungeon") == true and type(storage:GetAttribute("DungeonMap")) == "string"
                and storage:GetAttribute("DungeonCompleted") ~= true and not storage:GetAttribute("InTimeTrial")
                and not storage:GetAttribute("InfiniteDungeon") and room ~= nil
            if not canSearch then state.searchPosition = nil missingSince = nil continue end
            local now = os.clock()
            missingSince = missingSince or now
            if searchRoom ~= room then searchRoom, searchIndex, searchAt = room, 0, 0 end
            if now - missingSince >= 2 and now - searchAt >= 3 then
                local main = workspace:FindFirstChild("__Main")
                local points = dungeonSearchPoints(main and main:FindFirstChild("__World"), room)
                if #points > 0 then
                    searchIndex = searchIndex % #points + 1
                    state.searchPosition = points[searchIndex]
                    searchAt = now
                    local destination = state.searchPosition
                    task.spawn(function() pcall(function() player:RequestStreamAroundAsync(destination, 2) end) end)
                else state.searchPosition = nil end
            end
            if state.searchPosition then status.Text = "Buscando NPCs distantes nas salas carregadas..." end
            continue
        end
        state.searchPosition, missingSince = nil, nil
        status.Text = "Alvo: " .. tostring(target:GetAttribute("Id")) .. "\nHP: " .. tostring(enemyState.HP(target)) .. "\nMobs derrotados: " .. state.kills
        if not busy and (root.Position - target.Position).Magnitude <= 9 then
            busy = true
            local version = generation
            task.spawn(function()
                if alive and farmEnabled() and not state.leaving and not state.pumpkinBusy and os.clock() >= (state.entryUntil or 0) and version == generation and state.target == target and living(target, enemyFolder()) then
                    local success, problem = pcall(weapons.Click, {UserInputType = Enum.UserInputType.MouseButton1, KeyCode = Enum.KeyCode.ButtonX}, false)
                    if success then state.attacks += 1
                    else
                        state.enabled = false
                        dungeon.enabled = false
                        state.target = nil
                        refresh()
                        refreshDungeon()
                        status.Text = "Ataque interrompido: " .. tostring(problem)
                        warn("[AriseStudyHub] " .. tostring(problem))
                        save()
                    end
                end
                busy = false
            end)
        end
    end
end)
refresh()
print("[AriseStudyHub] Pronto: Farm, Dungeon e Misc. Estado do farm: " .. tostring(state.enabled))
]====]
local bootstrapSource = [====[
-- Continuidade da sessao atual do Roblox; nao usa a pasta autoexec.
local userId, resume = ...
if not game:IsLoaded() then game.Loaded:Wait() end
local player = game:GetService("Players").LocalPlayer
while not player do task.wait() player = game:GetService("Players").LocalPlayer end
if player.UserId ~= userId then return nil end
local env = getgenv()
local path = "AriseStudyHub/" .. userId .. ".json"
local function enabled()
    local ok, data = pcall(function() return game:GetService("HttpService"):JSONDecode(readfile(path)) end)
    return ok and type(data) == "table" and data.userId == userId and data.autoExecute == true
end
if not enabled() then return nil end
local previous = env.__AriseAutoSession
if previous and previous.version == 1 then return previous end
if previous and previous.connection then previous.connection:Disconnect() end
local queue = queue_on_teleport or queueonteleport or (syn and syn.queue_on_teleport)
if type(queue) ~= "function" then return nil end
local session = {version = 1, queued = false}
env.__AriseAutoSession = session
function session.arm()
    if session.queued or not enabled() then return end
    local source = string.format('local f = loadstring(readfile("AriseStudyHub/AutoExecute.luau")); if f then f(%s, true) end', tostring(userId))
    local ok, problem = pcall(queue, source)
    session.queued, session.problem = ok, not ok and tostring(problem) or nil
end
session.arm()
session.connection = player.OnTeleport:Connect(function(state)
    if state == Enum.TeleportState.Failed then session.queued = false session.arm() return end
    if state ~= Enum.TeleportState.Started then return end
    if session.beforeTeleport then session.beforeTeleport() end
    session.arm()
end)
if resume and game.GameId == 7074860883 then
    local deadline = os.clock() + 120
    local ready = false
    repeat
        local shared = game:GetService("ReplicatedStorage"):FindFirstChild("SharedModules")
        local scripts = player:FindFirstChild("PlayerScripts")
        local ui = scripts and scripts:FindFirstChild("NewUI", true)
        ready = shared and shared:FindFirstChild("WeaponsModule") and ui and ui:FindFirstChild("Screens")
        if ready then break end
        task.wait(0.5)
    until os.clock() >= deadline or not enabled()
    if ready and enabled() then
        local ok, problem = pcall(function()
            assert(loadstring(readfile("AriseStudyHub/Hub.luau")))()
        end)
        if not ok then warn("[AriseStudyHub] Auto Execute: " .. tostring(problem)) end
    end
end
return session
]====]
writefile("AriseStudyHub/Hub.luau", hubSource)
writefile("AriseStudyHub/AutoExecute.luau", bootstrapSource)
assert(loadstring(hubSource))()

