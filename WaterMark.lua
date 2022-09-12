local UserInputService = game:GetService("UserInputService")

local enabled = true 
if enabled then

--\\credits to DreiK and credits to warrior for fixing garbage code \\--
local ScreenGui = Instance.new("ScreenGui", game.CoreGui)
local Frame = Instance.new("Frame")
local TextLabel = Instance.new("TextLabel")
local TextLabel_2 = Instance.new("TextLabel")
local fps = Instance.new("TextLabel")

--Properties:

Frame.Parent = ScreenGui
Frame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
Frame.BorderColor3 = Color3.fromRGB(86, 86, 86)
Frame.BorderSizePixel = 2
Frame.Position = UDim2.new(0.0078125, 0, 0.0138888881, 0)
Frame.Size = UDim2.new(0, 210+#game.Players.LocalPlayer.Name, 0, 26)
Frame.Active = true

local gui = Frame

local dragging
local dragInput
local dragStart
local startPos

local function update(input)
local delta = input.Position - dragStart
gui.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
end

gui.InputBegan:Connect(function(input)
if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
dragging = true
dragStart = input.Position
startPos = gui.Position

input.Changed:Connect(function()
if input.UserInputState == Enum.UserInputState.End then
dragging = false
end
end)
end
end)

gui.InputChanged:Connect(function(input)
if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
dragInput = input
end
end)

UserInputService.InputChanged:Connect(function(input)
if input == dragInput and dragging then
update(input)
end
end)



TextLabel.Parent = Frame
TextLabel.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
TextLabel.BackgroundTransparency = 1.000
TextLabel.Size = UDim2.new(0, 45, 0, 26)
TextLabel.Font = Enum.Font.SourceSansBold
TextLabel.Text = "Syll"
TextLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
TextLabel.TextSize = 15.000

TextLabel_2.Parent = Frame
TextLabel_2.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
TextLabel_2.BackgroundTransparency = 1.000
TextLabel_2.Position = UDim2.new(0.142380973, 0, 0, 0)
TextLabel_2.Size = UDim2.new(0, 25, 0, 26)
TextLabel_2.Font = Enum.Font.SourceSansBold
TextLabel_2.Text = "inse"
TextLabel_2.TextColor3 = Color3.fromRGB(255, 162, 0)
TextLabel_2.TextSize = 14.000

fps.Name = "fps"
fps.Parent = Frame
fps.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
fps.BackgroundTransparency = 1.000
fps.Position = UDim2.new(0.574285731, 0, 0, 0)
fps.Size = UDim2.new(0, 25, 0, 26)
fps.Font = Enum.Font.SourceSansBold
fps.Text = "..."
fps.TextColor3 = Color3.fromRGB(255, 255, 255)
fps.TextSize = 14.000
spawn(function()while wait(1)do pcall(function()
local hour=os.date("*t")["hour"];
local min=os.date("*t")["min"];
if hour<10  then hour=string.format("0%s",hour)end;
if min<10 then min=string.format("0%s",min)end;
fps.Text=string.format("|  %s fps | %s:%s  |   %s",math.floor(game.Stats.Workspace.Heartbeat:GetValueString()),hour,min,game.Players.LocalPlayer.Name)end)end;end);

function zigzag(X)
return math.acos(math.cos(X * math.pi)) / math.pi
end

counter = 0

game:GetService("RunService").RenderStepped:Connect(function()
TextLabel_2.TextColor3 = Color3.fromHSV(zigzag(counter),1,1)
Frame.BorderColor3 = Color3.fromHSV(zigzag(counter),1,1)
counter = counter +  0.005-- change depending on how smooth you want
end)
end