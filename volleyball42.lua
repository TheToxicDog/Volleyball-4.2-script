-- Gravitational acceleration in Roblox
local GRAVITY = -30

-- Tolerance for deviation when the ball veers off course (in studs)
local DEVIATION_TOLERANCE = 2

-- Maximum distance for trajectory change cancellation (in studs)
local END_POSITION_TOLERANCE = 3

-- Variable to store the last trajectory end position
local lastEndPosition = nil

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

    -- Delete any old trajectory parts and lines before calculating a new one
    for _, obj in ipairs(workspace:GetChildren()) do
        if obj.Name == "TrajectoryPart" or obj.Name == "TrajectoryLine" then
            obj:Destroy()
        end
    end

    -- Draw trajectory visualization
    local trajectoryParts = {}
    local trajectoryLines = {}
    for i, point in ipairs(trajectoryPoints) do
        local part = Instance.new("Part")
        part.Name = "TrajectoryPart"  -- Name to easily identify it later for deletion
        part.Size = Vector3.new(0.2, 0.2, 0.2)
        part.Position = point
        part.Anchored = true
        part.CanCollide = false  -- Set CanCollide to false for all trajectory parts
        part.BrickColor = BrickColor.new("Bright red")  -- Initially red
        part.Parent = workspace
        table.insert(trajectoryParts, part)

        -- Connect the trajectory points with a neon green line
        if i < #trajectoryPoints then
            local nextPoint = trajectoryPoints[i + 1]
            local line = Instance.new("Part")
            line.Name = "TrajectoryLine"  -- Name to easily identify it later for deletion
            line.Size = Vector3.new(0.1, 0.1, (nextPoint - point).Magnitude)
            line.Position = (point + nextPoint) / 2
            line.Anchored = true
            line.CanCollide = false
            line.BrickColor = BrickColor.new("Lime green")  -- Neon green color
            line.Material = Enum.Material.Neon  -- Set material to Neon
            line.CFrame = CFrame.new(point, nextPoint)  -- Align with the direction of the line
            line.Parent = workspace
            table.insert(trajectoryLines, line)
        end
    end

    -- Monitor ball's position and velocity
    local currentIndex = 1
    game:GetService("RunService").Stepped:Connect(function(_, deltaTime)
        if not ball.Parent or #trajectoryParts == 0 then
            return
        end

        -- Get the current part to reach
        local currentPart = trajectoryParts[currentIndex]
        if currentPart then
            -- Calculate the distance between the ball's position and the trajectory point
            local distanceToPoint = (currentPart.Position - ballPart.Position).Magnitude
            
            -- If the ball is within the deviation tolerance, delete the part
            if distanceToPoint <= DEVIATION_TOLERANCE then
                -- Delete the trajectory part
                currentPart:Destroy()

                -- Delete the trajectory line between this part and the next
                if currentIndex < #trajectoryLines then
                    trajectoryLines[currentIndex]:Destroy()
                end

                -- Move to the next point
                currentIndex = currentIndex + 1
            elseif distanceToPoint > DEVIATION_TOLERANCE * 3 then
                -- Ball veered too far off course, delete all parts and recreate the trajectory
                -- Delete all previous trajectory parts and lines
                for _, part in ipairs(trajectoryParts) do
                    part:Destroy()
                end
                for _, line in ipairs(trajectoryLines) do
                    line:Destroy()
                end
                -- Recreate trajectory
                visualizeTrajectory(ball)
                return
            end
        end
    end)
end

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
