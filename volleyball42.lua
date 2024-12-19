-- Gravitational acceleration in Roblox
local GRAVITY = -30

-- Tolerance for deviation when the ball veers off course (in studs)
local DEVIATION_TOLERANCE = 2

-- Maximum distance for trajectory change cancellation (in studs)
local END_POSITION_TOLERANCE = 3

-- Variable to store the last trajectory end position
local lastEndPosition = nil

-- Constant number of trajectory parts
local NUM_TRAJECTORY_PARTS = 25

-- Table to store pre-created trajectory parts and lines
local trajectoryParts = {}
local trajectoryLines = {}

-- Function to create trajectory parts and lines once
local function createTrajectoryParts()
    for i = 1, NUM_TRAJECTORY_PARTS do
        -- Create trajectory parts
        local part = Instance.new("Part")
        part.Name = "TrajectoryPart"
        part.Size = Vector3.new(0.2, 0.2, 0.2)
        part.Anchored = true
        part.CanCollide = false
        part.BrickColor = BrickColor.new("Bright red")  -- Initially red
        part.Parent = workspace
        table.insert(trajectoryParts, part)

        -- Create trajectory lines
        if i < NUM_TRAJECTORY_PARTS then
            local line = Instance.new("Part")
            line.Name = "TrajectoryLine"
            line.Size = Vector3.new(0.1, 0.1, 1)
            line.Anchored = true
            line.CanCollide = false
            line.BrickColor = BrickColor.new("Lime green")  -- Neon green color
            line.Material = Enum.Material.Neon  -- Set material to Neon
            line.Parent = workspace
            table.insert(trajectoryLines, line)
        end
    end
end

-- Function to calculate trajectory and visualize it
local function visualizeTrajectory(ball)
    -- Get the current end position of the trajectory
    local velocity = ball:FindFirstChild("Velocity")
    local ballPart = ball:FindFirstChild("BallPart")
    
    if not velocity or not velocity:IsA("Vector3Value") or not ballPart then
        warn(ball.Name .. " does not have valid velocity or BallPart.")
        return
    end

    local initialPosition = ballPart.Position
    local initialVelocity = velocity.Value
    local yFloor = 0

    -- Calculate when the ball hits the floor (y = 0)
    local a = 0.5 * GRAVITY
    local b = initialVelocity.Y
    local c = initialPosition.Y - yFloor
    local discriminant = b^2 - 4 * a * c

    if discriminant < 0 then
        warn("Ball trajectory does not reach the floor.")
        return
    end

    -- Time when the ball hits the floor
    local tHit = (-b - math.sqrt(discriminant)) / (2 * a)

    if tHit < 0 then
        warn("Ball is moving away from the floor.")
        return
    end

    -- Create trajectory points
    local trajectoryPoints = {}
    local timeStep = 0.1
    local maxTime = tHit + 1  -- Add a small buffer to ensure we visualize the trajectory even if the ball is very close to the floor
    for t = 0, maxTime, timeStep do
        local x = initialPosition.X + initialVelocity.X * t
        local y = initialPosition.Y + initialVelocity.Y * t + 0.5 * GRAVITY * t^2
        local z = initialPosition.Z + initialVelocity.Z * t
        table.insert(trajectoryPoints, Vector3.new(x, y, z))

        -- Stop generating trajectory if the ball's vertical velocity becomes near zero (indicating it has stopped falling)
        if math.abs(initialVelocity.Y + GRAVITY * t) < 0.1 then
            break
        end
    end

    local newEndPosition = trajectoryPoints[#trajectoryPoints]

    -- If the new end position is within END_POSITION_TOLERANCE of the last end position, cancel the update
    if lastEndPosition and (newEndPosition - lastEndPosition).Magnitude <= END_POSITION_TOLERANCE then
        return
    end

    -- Update the last end position
    lastEndPosition = newEndPosition

    -- Move trajectory parts and lines along the trajectory
    local currentIndex = 1
    local maxParts = math.min(#trajectoryPoints, NUM_TRAJECTORY_PARTS)
    for i = 1, maxParts do
        local point = trajectoryPoints[i]
        local part = trajectoryParts[i]
        local line = trajectoryLines[i]

        -- Move the trajectory part
        part.Position = point

        -- Update the trajectory line between this part and the next (if exists)
        if i < maxParts then
            local nextPoint = trajectoryPoints[i + 1]
            line.Size = Vector3.new(0.1, 0.1, (nextPoint - point).Magnitude)
            line.Position = (point + nextPoint) / 2
            line.CFrame = CFrame.new(point, nextPoint)
        end
    end

    -- Monitor ball's position and velocity
    game:GetService("RunService").Stepped:Connect(function(_, deltaTime)
        if not ball.Parent or #trajectoryParts == 0 then
            return
        end

        -- Get the current part to reach
        local currentPart = trajectoryParts[currentIndex]
        if currentPart then
            -- Calculate the distance between the ball's position and the trajectory point
            local distanceToPoint = (currentPart.Position - ballPart.Position).Magnitude
            
            -- If the ball is within the deviation tolerance, move to the next part
            if distanceToPoint <= DEVIATION_TOLERANCE then
                -- Move to the next part
                currentIndex = currentIndex + 1
            elseif distanceToPoint > DEVIATION_TOLERANCE * 3 then
                -- Ball veered too far off course, recalculate trajectory
                -- Recreate trajectory visualization
                visualizeTrajectory(ball)
                return
            end
        end
    end)
end

-- Create trajectory parts and lines when the game starts
createTrajectoryParts()

-- Listen for new balls added to the workspace and visualize their trajectory
workspace.ChildAdded:Connect(function(child)
    if child.Name == "Ball" then
        -- Wait for the 'Spawner' child to be added to the ball
        local spawner = child:WaitForChild("Spawner")
        
        if spawner and spawner:IsA("StringValue") then
            local playerName = spawner.Value  -- Get the player who spawned the ball
            local player = game.Players:FindFirstChild(playerName)

            if player and player.Team and player.Team.Name ~= "Player" then
                -- Only visualize the trajectory for game balls
                visualizeTrajectory(child)  -- Visualize the trajectory for game balls
            end
        end
    end
end)
