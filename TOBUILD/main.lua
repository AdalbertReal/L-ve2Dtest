-- Global state and helper function
gameState = "title" -- Can be "title", "playing", "paused", "gameOver"

function sign(x) return x > 0 and 1 or x < 0 and -1 or 0 end

function love.load()
    love.window.setMode(1366, 768, {resizable = true})
    highScore = 0

    -- Generate background pattern
    bgStars = {}
    for i = 1, 500 do
        table.insert(bgStars, {
            x = love.math.random(-3000, 3000),
            y = love.math.random(-3000, 3000),
            size = love.math.random(1, 3)
        })
    end
end

function resetGame()
    x = 400
    y = 300
    speed = 200
    hp = 100
    maxHp = 100
    ammo = 30
    maxAmmo = 30
    shipX = x
    shipY = y
    shipAngle = 0
    trails = {}
    bullets = {}
    shootCooldown = 0
    particles = {}
    powerups = {}
    fireRate = 0.5
    fireRateBoosts = 0
    bulletSize = 3
    bulletSizeBoosts = 0
    radarZoomBoosts = 0
    gameTime = 0
    enemies = {}
    enemySpeed = 50
    enemyChaseSpeed = 150
    enemyTurnSpeed = 1 -- Radians per second
    detectionRange = 1000
    enemyBullets = {}
    enemyShootCooldown = 2
    enemyBulletSpeed = 250
    arenaMinX = -2500
    arenaMaxX = 2500
    arenaMinY = -2500
    arenaMaxY = 2500
    killMinX = -4000
    killMaxX = 4000
    killMinY = -4000
    killMaxY = 4000
    spawnTimer = 0
    chaserSpawnTimer = 0
    prevShipAngle = 0
    turning = false
    asteroids = {}
    for i = 1, 30 do
        local ast = {
            x = love.math.random(-2000, 2000),
            y = love.math.random(-2000, 2000),
            vx = love.math.random(-50, 50),
            vy = love.math.random(-50, 50),
            size = love.math.random(20, 60)
        }
        ast.points = {}
        local sides = love.math.random(6, 12)
        for j = 0, sides - 1 do
            local angle = j * 2 * math.pi / sides
            local r = ast.size * (0.7 + love.math.random() * 0.6)  -- vary radius for irregular shape
            table.insert(ast.points, math.cos(angle) * r)
            table.insert(ast.points, math.sin(angle) * r)
        end
        table.insert(asteroids, ast)
    end

    enemies = {}
    for i = 1, 10 do
        local enemy = {
            x = love.math.random(-2000, 2000),
            y = love.math.random(-2000, 2000),
            vx = 0,
            vy = 0,
            angle = love.math.random() * 2 * math.pi,
            changeTimer = 0,
            state = "patrol",
            type = "chaser"
        }
        table.insert(enemies, enemy)
    end

    -- Spawn guard enemy and power-up cache
    local guardCacheX = 1500
    local guardCacheY = 1500
    table.insert(powerups, {x = guardCacheX - 30, y = guardCacheY, type = "fireRate"})
    table.insert(powerups, {x = guardCacheX + 30, y = guardCacheY, type = "bulletSize"})
    table.insert(powerups, {x = guardCacheX, y = guardCacheY - 30, type = "radarZoom"})

    local guard = {
        x = guardCacheX,
        y = guardCacheY,
        vx = 0,
        vy = 0,
        angle = 0,
        state = "patrol",
        type = "guard",
        guardPointX = guardCacheX,
        guardPointY = guardCacheY,
        guardRadius = 400,
        patrolTargetX = guardCacheX,
        patrolTargetY = guardCacheY,
        shootTimer = enemyShootCooldown
    }
    table.insert(enemies, guard)
end

function love.update(dt)
    if gameState ~= "playing" then return end
    gameTime = gameTime + dt

    -- Dynamic difficulty: increase caps over time
    local currentMaxAsteroids = 50 + math.floor(gameTime / 3) -- +1 asteroid cap every 3s
    local currentMaxChasers = 10 + math.floor(gameTime / 2) -- +1 chaser cap every 2s

    if love.keyboard.isDown("right") or love.keyboard.isDown("d") then
        x = x + (speed * dt)
    end
    if love.keyboard.isDown("left") or love.keyboard.isDown("a") then
        x = x - (speed * dt)
    end
    if love.keyboard.isDown("up") or love.keyboard.isDown("w") then
        y = y - (speed * dt)
    end
    if love.keyboard.isDown("down") or love.keyboard.isDown("s") then
        y = y + (speed * dt)
    end

    -- Clamp x and y to arena bounds
    x = math.max(arenaMinX, math.min(arenaMaxX, x))
    y = math.max(arenaMinY, math.min(arenaMaxY, y))

    local dx = x - shipX
    local dy = y - shipY
    if math.abs(dx) > 0.1 or math.abs(dy) > 0.1 then
        shipAngle = math.atan2(dy, dx)

        -- Add trails
        local angle = shipAngle + math.pi/2
        local cosA = math.cos(angle)
        local sinA = math.sin(angle)
        table.insert(trails, {x = shipX + (-20 * cosA - 25 * sinA), y = shipY + (-20 * sinA + 25 * cosA), life = 0.5})
        table.insert(trails, {x = shipX + (20 * cosA - 25 * sinA), y = shipY + (20 * sinA + 25 * cosA), life = 0.5})
    end

    -- Detect turning
    local angleDiff = shipAngle - prevShipAngle
    angleDiff = (angleDiff + math.pi) % (2 * math.pi) - math.pi  -- normalize to -pi to pi
    turningLeft = angleDiff < -0.01
    turningRight = angleDiff > 0.01
    prevShipAngle = shipAngle
    shipX = shipX + dx * 5 * dt
    shipY = shipY + dy * 5 * dt

    -- Clamp player to arena bounds
    shipX = math.max(arenaMinX, math.min(arenaMaxX, shipX))
    shipY = math.max(arenaMinY, math.min(arenaMaxY, shipY))

    -- Autofire
    shootCooldown = shootCooldown - dt
    if love.keyboard.isDown("space") and shootCooldown <= 0 then
        local bulletSpeed = 500
        local vx = math.cos(shipAngle) * bulletSpeed
        local vy = math.sin(shipAngle) * bulletSpeed
        table.insert(bullets, {x = shipX, y = shipY, vx = vx, vy = vy, life = 3, size = bulletSize})
        shootCooldown = fireRate  -- use current fire rate
    end

    -- Update trails
    for i = #trails, 1, -1 do
        trails[i].life = trails[i].life - dt
        if trails[i].life <= 0 then
            table.remove(trails, i)
        end
    end

    -- Update bullets
    for i = #bullets, 1, -1 do
        local bullet = bullets[i]
        bullet.x = bullet.x + bullet.vx * dt
        bullet.y = bullet.y + bullet.vy * dt

        -- Check collision with asteroids
        local hit = false
        for j = #asteroids, 1, -1 do
            local ast = asteroids[j]
            local dx = bullet.x - ast.x
            local dy = bullet.y - ast.y
            local dist = math.sqrt(dx*dx + dy*dy)
            if dist < ast.size + (bullet.size or 3) then  -- bullet radius
                -- Spawn particles
                for k = 1, 8 do
                    table.insert(particles, {
                        x = ast.x,
                        y = ast.y,
                        vx = love.math.random(-200, 200),
                        vy = love.math.random(-200, 200),
                        life = 0.5
                    })
                end
                -- Chance to spawn powerup
                local rand = love.math.random()
                if rand < 0.05 then
                    table.insert(powerups, {x = ast.x, y = ast.y, type = "fireRate"})
                elseif rand < 0.1 then
                    table.insert(powerups, {x = ast.x, y = ast.y, type = "bulletSize"})
                elseif rand < 0.15 then
                    table.insert(powerups, {x = ast.x, y = ast.y, type = "radarZoom"})
                end
                table.remove(asteroids, j)
                hit = true
                break
            end
        end

        -- Check collision with enemies if not already hit an asteroid
        if not hit then
            for j = #enemies, 1, -1 do
                local enemy = enemies[j]
                local dx = bullet.x - enemy.x
                local dy = bullet.y - enemy.y
                if math.sqrt(dx*dx + dy*dy) < 20 then -- Approx enemy radius
                    -- Spawn particles
                    for k = 1, 8 do
                        table.insert(particles, {
                            x = enemy.x, y = enemy.y,
                            vx = love.math.random(-200, 200), vy = love.math.random(-200, 200),
                            life = 0.5
                        })
                    end
                    table.remove(enemies, j)
                    hit = true
                    break
                end
            end
        end

        -- Remove bullet if it hit something, or if its life expired
        if hit then
            table.remove(bullets, i)
        else
            bullet.life = bullet.life - dt
            if bullet.life <= 0 then
                table.remove(bullets, i)
            end
        end
    end

    -- Update asteroids and collisions
    for i = #asteroids, 1, -1 do
        local ast = asteroids[i]
        ast.x = ast.x + ast.vx * dt
        ast.y = ast.y + ast.vy * dt
    end

    -- Asteroid-asteroid collisions
    for i = 1, #asteroids do
        for j = i + 1, #asteroids do
            local a = asteroids[i]
            local b = asteroids[j]
            local dx = b.x - a.x
            local dy = b.y - a.y
            local dist = math.sqrt(dx * dx + dy * dy)
            if dist < a.size + b.size then
                local nx = dx / dist
                local ny = dy / dist
                local rvx = b.vx - a.vx
                local rvy = b.vy - a.vy
                local rv = rvx * nx + rvy * ny
                if rv < 0 then
                    local restitution = 1
                    local mA = a.size
                    local mB = b.size
                    local impulse = (1 + restitution) * rv / (1 / mA + 1 / mB)
                    a.vx = a.vx + impulse / mA * nx
                    a.vy = a.vy + impulse / mA * ny
                    b.vx = b.vx - impulse / mB * nx
                    b.vy = b.vy - impulse / mB * ny
                end
            end
        end
    end

    -- Check asteroid-player collisions
    for i = #asteroids, 1, -1 do
        local ast = asteroids[i]
        local dx = ast.x - shipX
        local dy = ast.y - shipY
        local dist = math.sqrt(dx*dx + dy*dy)
        if dist < ast.size + 25 then  -- approximate ship radius
            -- Spawn particles
            for k = 1, 8 do
                table.insert(particles, {
                    x = ast.x,
                    y = ast.y,
                    vx = love.math.random(-200, 200),
                    vy = love.math.random(-200, 200),
                    life = 0.5
                })
            end
            hp = hp - 20  -- take damage
            if hp <= 0 then
                gameState = "gameOver"
                highScore = math.max(highScore, gameTime)
            end
            table.remove(asteroids, i)
        end
    end

    -- Update enemies
    for i = #enemies, 1, -1 do
        local enemy = enemies[i]
        local currentSpeed

        if enemy.type == "chaser" then
            local dx = shipX - enemy.x
            local dy = shipY - enemy.y
            local dist = math.sqrt(dx*dx + dy*dy)
            if dist < detectionRange then
                -- Chase player
                enemy.state = "chasing"
                local targetAngle = math.atan2(dy, dx)
                local angleDiff = targetAngle - enemy.angle
                -- Normalize angle difference to the range [-pi, pi] to find the shortest path
                angleDiff = (angleDiff + math.pi) % (2 * math.pi) - math.pi

                local turnAmount = enemyTurnSpeed * dt
                if math.abs(angleDiff) < turnAmount then
                    enemy.angle = targetAngle
                else
                    enemy.angle = enemy.angle + sign(angleDiff) * turnAmount
                end
                currentSpeed = enemyChaseSpeed
            else
                -- If the enemy was just chasing, make it switch back to patrol immediately
                if enemy.state == "chasing" then
                    enemy.state = "patrol"
                    enemy.changeTimer = 2 -- Force immediate direction change
                end

                -- Patrol
                enemy.changeTimer = enemy.changeTimer + dt
                if enemy.changeTimer > 2 then
                    -- New direction is biased towards the center (0,0)
                    local distFromCenter = math.sqrt(enemy.x^2 + enemy.y^2)
                    -- Bias is stronger the further out they are. arenaMaxX is 2500.
                    local biasFactor = math.min(1, distFromCenter / arenaMaxX)

                    -- The angle pointing directly to the center
                    local angleToCenter = math.atan2(-enemy.y, -enemy.x)

                    -- The further out, the smaller the random deviation from the center-pointing angle
                    -- At center (bias=0), deviation is +/- PI (fully random)
                    -- At edge (bias=1), deviation is +/- PI/4 (90 degree cone towards center)
                    local maxDeviation = math.pi * (1 - 0.75 * biasFactor)
                    local randomOffset = love.math.random() * 2 * maxDeviation - maxDeviation
                    enemy.angle = angleToCenter + randomOffset
                    enemy.changeTimer = 0
                end
                currentSpeed = enemySpeed
            end
        elseif enemy.type == "guard" then
            local dx_player = shipX - enemy.x
            local dy_player = shipY - enemy.y
            local dist_player = math.sqrt(dx_player*dx_player + dy_player*dy_player)

            if dist_player < detectionRange then
                -- Attack player
                enemy.state = "attacking"
                local targetAngle = math.atan2(dy_player, dx_player)
                -- Turn to face player
                local angleDiff = targetAngle - enemy.angle
                angleDiff = (angleDiff + math.pi) % (2 * math.pi) - math.pi
                local turnAmount = enemyTurnSpeed * dt
                if math.abs(angleDiff) < turnAmount then
                    enemy.angle = targetAngle
                else
                    enemy.angle = enemy.angle + sign(angleDiff) * turnAmount
                end

                -- Shoot at player
                enemy.shootTimer = enemy.shootTimer - dt
                if enemy.shootTimer <= 0 then
                    local vx = math.cos(enemy.angle) * enemyBulletSpeed
                    local vy = math.sin(enemy.angle) * enemyBulletSpeed
                    table.insert(enemyBullets, {x = enemy.x, y = enemy.y, vx = vx, vy = vy, life = 4})
                    enemy.shootTimer = enemyShootCooldown
                end
                -- Guards don't move when attacking
                currentSpeed = 0
            else
                -- Patrol guard area
                if enemy.state == "attacking" then
                    enemy.state = "patrol"
                end
                local dx_patrol = enemy.patrolTargetX - enemy.x
                local dy_patrol = enemy.patrolTargetY - enemy.y
                if math.sqrt(dx_patrol*dx_patrol + dy_patrol*dy_patrol) < 20 then
                    -- New patrol point
                    local randomAngle = love.math.random() * 2 * math.pi
                    local randomDist = love.math.random() * enemy.guardRadius
                    enemy.patrolTargetX = enemy.guardPointX + math.cos(randomAngle) * randomDist
                    enemy.patrolTargetY = enemy.guardPointY + math.sin(randomAngle) * randomDist
                end
                local targetAngle = math.atan2(enemy.patrolTargetY - enemy.y, enemy.patrolTargetX - enemy.x)
                -- Turn towards patrol point
                local angleDiff = targetAngle - enemy.angle
                angleDiff = (angleDiff + math.pi) % (2 * math.pi) - math.pi
                local turnAmount = enemyTurnSpeed * dt
                if math.abs(angleDiff) < turnAmount then
                    enemy.angle = targetAngle
                else
                    enemy.angle = enemy.angle + sign(angleDiff) * turnAmount
                end
                currentSpeed = enemySpeed
            end
        end

        enemy.vx = math.cos(enemy.angle) * currentSpeed
        enemy.vy = math.sin(enemy.angle) * currentSpeed
        enemy.x = enemy.x + enemy.vx * dt
        enemy.y = enemy.y + enemy.vy * dt
        -- Clamp to arena
        -- Remove if out of kill boundary
        if enemy.x < killMinX or enemy.x > killMaxX or enemy.y < killMinY or enemy.y > killMaxY then
            table.remove(enemies, i)
        end
    end

    -- Check enemy-player collisions
    for i = #enemies, 1, -1 do
        local enemy = enemies[i]
        local dx = enemy.x - shipX
        local dy = enemy.y - shipY
        local dist = math.sqrt(dx*dx + dy*dy)
        if dist < 25 then  -- approximate ship radius
            hp = hp - 20  -- take damage
            if hp <= 0 then
                gameState = "gameOver"
                highScore = math.max(highScore, gameTime)
            end
            table.remove(enemies, i)
        end
    end

    -- Update enemy bullets and check collision with player
    for i = #enemyBullets, 1, -1 do
        local bullet = enemyBullets[i]
        bullet.x = bullet.x + bullet.vx * dt
        bullet.y = bullet.y + bullet.vy * dt
        bullet.life = bullet.life - dt

        local dx = bullet.x - shipX
        local dy = bullet.y - shipY
        if math.sqrt(dx*dx + dy*dy) < 25 then -- player radius
            hp = hp - 10 -- less damage than ramming
            if hp <= 0 then
                gameState = "gameOver"
                highScore = math.max(highScore, gameTime)
            end
            table.remove(enemyBullets, i)
        elseif bullet.life <= 0 then
            table.remove(enemyBullets, i)
        end
    end

    -- Update powerups movement (magnetism, arena pull)
    local magnetRadius = 150
    local magnetStrength = 200
    local arenaPullSpeed = 100
    for _, pu in ipairs(powerups) do
        -- Magnetism towards player
        local dx_player = x - pu.x
        local dy_player = y - pu.y
        local dist_player = math.sqrt(dx_player*dx_player + dy_player*dy_player)

        if dist_player < magnetRadius and dist_player > 0.1 then -- avoid div by zero
            local pull_speed = magnetStrength * (1 - dist_player / magnetRadius)
            pu.x = pu.x + (dx_player / dist_player) * pull_speed * dt
            pu.y = pu.y + (dy_player / dist_player) * pull_speed * dt
        end

        -- Pull towards arena if outside
        if pu.x < arenaMinX then
            pu.x = pu.x + arenaPullSpeed * dt
        elseif pu.x > arenaMaxX then
            pu.x = pu.x - arenaPullSpeed * dt
        end
        if pu.y < arenaMinY then
            pu.y = pu.y + arenaPullSpeed * dt
        elseif pu.y > arenaMaxY then
            pu.y = pu.y - arenaPullSpeed * dt
        end
    end

    -- Check powerup collision
    for i = #powerups, 1, -1 do
        local pu = powerups[i]
        local dx = pu.x - x
        local dy = pu.y - y
        local dist = math.sqrt(dx*dx + dy*dy)
        if dist < 30 then  -- pickup radius
            if pu.type == "fireRate" then
                fireRate = fireRate * 0.8  -- increase fire rate
                fireRateBoosts = fireRateBoosts + 1
            elseif pu.type == "bulletSize" then
                bulletSize = bulletSize + 2
                bulletSizeBoosts = bulletSizeBoosts + 1
            elseif pu.type == "radarZoom" then
                radarZoomBoosts = radarZoomBoosts + 1
            end
            table.remove(powerups, i)
        end
    end

    -- Update particles
    for i = #particles, 1, -1 do
        particles[i].x = particles[i].x + particles[i].vx * dt
        particles[i].y = particles[i].y + particles[i].vy * dt
        particles[i].life = particles[i].life - dt
        if particles[i].life <= 0 then
            table.remove(particles, i)
        end
    end

    -- Remove objects outside kill boundary
    for i = #asteroids, 1, -1 do
        if asteroids[i].x < killMinX or asteroids[i].x > killMaxX or asteroids[i].y < killMinY or asteroids[i].y > killMaxY then
            table.remove(asteroids, i)
        end
    end
    for i = #bullets, 1, -1 do
        if bullets[i].x < killMinX or bullets[i].x > killMaxX or bullets[i].y < killMinY or bullets[i].y > killMaxY then
            table.remove(bullets, i)
        end
    end
    for i = #particles, 1, -1 do
        if particles[i].x < killMinX or particles[i].x > killMaxX or particles[i].y < killMinY or particles[i].y > killMaxY then
            table.remove(particles, i)
        end
    end

    -- Spawn new asteroids near kill boundary
    if #asteroids < currentMaxAsteroids then
        local ratio = #asteroids / currentMaxAsteroids
        local currentInterval = 2 * ratio
        spawnTimer = spawnTimer + dt
        if spawnTimer > currentInterval then
            spawnTimer = 0
            local side = love.math.random(1, 4)  -- 1:left, 2:right, 3:top, 4:bottom
            local ast = {
                size = love.math.random(20, 60),
                points = {}
            }
            local sides = love.math.random(6, 12)
            for i = 1, sides do
                local angle = (i - 1) / sides * 2 * math.pi
                local radius = ast.size + love.math.random(-5, 5)
                table.insert(ast.points, radius * math.cos(angle))
                table.insert(ast.points, radius * math.sin(angle))
            end
            if side == 1 then  -- left
                local angle = love.math.random(-math.pi/6, math.pi/6)
                local speed = love.math.random(50, 100)
                ast.x = killMinX + 10
                ast.y = love.math.random(killMinY, killMaxY)
                ast.vx = speed * math.cos(angle)
                ast.vy = speed * math.sin(angle)
            elseif side == 2 then  -- right
                local angle = math.pi + love.math.random(-math.pi/6, math.pi/6)
                local speed = love.math.random(50, 100)
                ast.x = killMaxX - 10
                ast.y = love.math.random(killMinY, killMaxY)
                ast.vx = speed * math.cos(angle)
                ast.vy = speed * math.sin(angle)
            elseif side == 3 then  -- top
                local angle = -math.pi/2 + love.math.random(-math.pi/6, math.pi/6)
                local speed = love.math.random(50, 100)
                ast.x = love.math.random(killMinX, killMaxX)
                ast.y = killMaxY - 10
                ast.vx = speed * math.cos(angle)
                ast.vy = speed * math.sin(angle)
            elseif side == 4 then  -- bottom
                local angle = math.pi/2 + love.math.random(-math.pi/6, math.pi/6)
                local speed = love.math.random(50, 100)
                ast.x = love.math.random(killMinX, killMaxX)
                ast.y = killMinY + 10
                ast.vx = speed * math.cos(angle)
                ast.vy = speed * math.sin(angle)
            end
            table.insert(asteroids, ast)
        end
    end

    -- Spawn new chaser enemies
    local chaserCount = 0
    for _, e in ipairs(enemies) do
        if e.type == "chaser" then
            chaserCount = chaserCount + 1
        end
    end

    if chaserCount < currentMaxChasers then
        chaserSpawnTimer = chaserSpawnTimer + dt
        if chaserSpawnTimer > 1 then -- spawn a chaser every 1 second if below cap
            chaserSpawnTimer = 0
            
            local side = love.math.random(1, 4)
            local x, y, spawnAngle
            if side == 1 then -- left
                x = killMinX + 10
                y = love.math.random(killMinY, killMaxY)
                spawnAngle = love.math.random(-math.pi/4, math.pi/4)
            elseif side == 2 then -- right
                x = killMaxX - 10
                y = love.math.random(killMinY, killMaxY)
                spawnAngle = math.pi + love.math.random(-math.pi/4, math.pi/4)
            elseif side == 3 then -- top
                x = love.math.random(killMinX, killMaxX)
                y = killMaxY - 10
                spawnAngle = -math.pi/2 + love.math.random(-math.pi/4, math.pi/4)
            else -- bottom
                x = love.math.random(killMinX, killMaxX)
                y = killMinY + 10
                spawnAngle = math.pi/2 + love.math.random(-math.pi/4, math.pi/4)
            end

            local enemy = {
                x = x, y = y, vx = 0, vy = 0,
                angle = spawnAngle,
                changeTimer = 0, state = "patrol", type = "chaser"
            }
            table.insert(enemies, enemy)
        end
    end
end

function love.draw()
    if gameState == "title" then
        love.graphics.clear(0, 0, 0.1)
        love.graphics.setColor(1, 1, 1)
        local w, h = love.graphics.getDimensions()
        love.graphics.printf("ASTEROID CHAOS", 0, h/2 - 100, w, "center")
        love.graphics.printf("Use WASD or Arrow Keys to move", 0, h/2, w, "center")
        love.graphics.printf("Use Space to shoot", 0, h/2 + 20, w, "center")
        love.graphics.printf("Press 'P' to pause", 0, h/2 + 40, w, "center")
        love.graphics.printf("Press R to Start", 0, h/2 + 80, w, "center")
        return
    end

    -- The rest of the drawing happens for "playing", "paused", and "gameOver" states
    -- so we can see the game world in the background.

    love.graphics.clear(0, 0, 0)
    local scale = math.min(love.graphics.getWidth() / 1366, love.graphics.getHeight() / 768)
    local offsetX = (love.graphics.getWidth() - 1366 * scale) / 2
    local offsetY = (love.graphics.getHeight() - 768 * scale) / 2
    love.graphics.push()
    love.graphics.translate(offsetX, offsetY)
    love.graphics.scale(scale, scale)

    -- Camera follows the player
    love.graphics.translate(1366/2 - shipX, 768/2 - shipY)

    -- Draw background
    love.graphics.setColor(0.5, 0.5, 0.5)
    for _, star in ipairs(bgStars) do
        love.graphics.circle("fill", star.x, star.y, star.size)
    end

    -- Draw asteroids
    love.graphics.setColor(0.6, 0.6, 0.6)
    for _, ast in ipairs(asteroids) do
        love.graphics.push()
        love.graphics.translate(ast.x, ast.y)
        love.graphics.polygon("fill", unpack(ast.points))
        love.graphics.pop()
    end

    -- Draw enemies
    for _, enemy in ipairs(enemies) do
        love.graphics.push()
        love.graphics.translate(enemy.x, enemy.y)
        if enemy.type == "chaser" then
            love.graphics.setColor(1, 0, 0)
            love.graphics.rotate(enemy.angle + math.pi/2)
            love.graphics.polygon("fill", 0, -15, -10, 15, 10, 15)
        elseif enemy.type == "guard" then
            love.graphics.setColor(0.8, 0, 1) -- Purple
            love.graphics.rotate(enemy.angle) -- Guard model is oriented along X axis
            love.graphics.polygon("fill", -15, -15, 15, -15, 15, 15, -15, 15)
            love.graphics.setColor(1, 1, 1)
            love.graphics.polygon("fill", 10, -5, 15, 0, 10, 5) -- "eye" pointing forward
        end
        love.graphics.pop()
    end

    -- Draw particles
    for _, p in ipairs(particles) do
        love.graphics.setColor(0.8, 0.8, 0.8, p.life * 2)
        love.graphics.circle("fill", p.x, p.y, 2)
    end

    -- Draw enemy bullets
    love.graphics.setColor(1, 0.5, 0) -- Orange
    for _, bullet in ipairs(enemyBullets) do
        love.graphics.circle("fill", bullet.x, bullet.y, 4)
    end

    -- Draw powerups
    for _, pu in ipairs(powerups) do
        if pu.type == "fireRate" then
            love.graphics.setColor(1, 1, 0)  -- yellow
            love.graphics.circle("fill", pu.x, pu.y, 12)
            love.graphics.setColor(1, 1, 1)
            love.graphics.circle("line", pu.x, pu.y, 12)
        elseif pu.type == "bulletSize" then
            love.graphics.setColor(1, 0, 0)  -- red
            love.graphics.circle("fill", pu.x, pu.y, 12)
            love.graphics.setColor(1, 1, 1)
            love.graphics.circle("line", pu.x, pu.y, 12)
        elseif pu.type == "radarZoom" then
            love.graphics.setColor(0, 0, 1)  -- blue
            love.graphics.circle("fill", pu.x, pu.y, 12)
            love.graphics.setColor(1, 1, 1)
            love.graphics.circle("line", pu.x, pu.y, 12)
        end
    end

    -- Draw trails
    for _, trail in ipairs(trails) do
        love.graphics.setColor(0, 0.8, 1, trail.life * 2)  -- fade out
        love.graphics.circle("fill", trail.x, trail.y, 5 * trail.life)
    end

    -- Draw bullets
    love.graphics.setColor(1, 1, 0)
    for _, bullet in ipairs(bullets) do
        love.graphics.circle("fill", bullet.x, bullet.y, bullet.size or 3)
    end

    -- Draw particles
    love.graphics.setColor(1, 1, 0)
    for _, bullet in ipairs(bullets) do
        love.graphics.circle("fill", bullet.x, bullet.y, 3)
    end

    -- Ship triangle (graphic representation)
    love.graphics.setColor(0, 0.8, 1)
    love.graphics.push()
    love.graphics.translate(shipX, shipY)
    love.graphics.rotate(shipAngle + math.pi/2)
    love.graphics.polygon("fill", -25, 25, 0, -25, 25, 25)

    -- Thrusters
    love.graphics.setColor(1, 0.5, 0)  -- orange
    if turningLeft then
        -- Turning left, fire right thruster
        love.graphics.polygon("fill", 15, 5, 9, -5, 22.5, 5)
    elseif turningRight then
        -- Turning right, fire left thruster
        love.graphics.polygon("fill", -15, 5, -9, -5, -22.5, -5)
    end

    love.graphics.pop()

    -- Draw arena boundary if close
    local distToLeft = shipX - arenaMinX
    local distToRight = arenaMaxX - shipX
    local distToBottom = shipY - arenaMinY
    local distToTop = arenaMaxY - shipY
    local minDist = math.min(distToLeft, distToRight, distToBottom, distToTop)
    local fadeDist = 500
    local alpha = 0
    if minDist < fadeDist then
        alpha = (fadeDist - minDist) / fadeDist
    end
    if alpha > 0 then
        love.graphics.setColor(1, 1, 1, alpha)
        love.graphics.setLineWidth(2)
        local dotLength = 10
        local gap = 10
        local step = dotLength + gap
        local time = love.timer.getTime()
        local speed = 50
        local offset = (time * speed) % step
        -- Bottom
        for x = arenaMinX + offset, arenaMaxX, step do
            if x + dotLength <= arenaMaxX then
                love.graphics.line(x, arenaMinY, x + dotLength, arenaMinY)
            end
        end
        -- Top
        for x = arenaMinX + offset, arenaMaxX, step do
            if x + dotLength <= arenaMaxX then
                love.graphics.line(x, arenaMaxY, x + dotLength, arenaMaxY)
            end
        end
        -- Left
        for y = arenaMinY + offset, arenaMaxY, step do
            if y + dotLength <= arenaMaxY then
                love.graphics.line(arenaMinX, y, arenaMinX, y + dotLength)
            end
        end
        -- Right
        for y = arenaMinY + offset, arenaMaxY, step do
            if y + dotLength <= arenaMaxY then
                love.graphics.line(arenaMaxX, y, arenaMaxX, y + dotLength)
            end
        end
    end

    love.graphics.pop()
    drawUI()

    if gameState == "paused" then
        love.graphics.setColor(0, 0, 0, 0.5)
        love.graphics.rectangle("fill", 0, 0, love.graphics.getWidth(), love.graphics.getHeight())
        love.graphics.setColor(1, 1, 1)
        love.graphics.printf("PAUSED", 0, love.graphics.getHeight()/2 - 50, love.graphics.getWidth(), "center")
        love.graphics.printf("Press P to Resume", 0, love.graphics.getHeight()/2, love.graphics.getWidth(), "center")
    elseif gameState == "gameOver" then
        -- Game over screen
        love.graphics.setColor(0, 0, 0, 0.7)
        love.graphics.rectangle("fill", 0, 0, love.graphics.getWidth(), love.graphics.getHeight())
        love.graphics.setColor(1, 1, 1)
        love.graphics.printf("GAME OVER", 0, love.graphics.getHeight()/2 - 50, love.graphics.getWidth(), "center")
        love.graphics.printf(string.format("Final Time: %.1f", gameTime), 0, love.graphics.getHeight()/2 - 20, love.graphics.getWidth(), "center")
        love.graphics.printf("Press R to Restart", 0, love.graphics.getHeight()/2, love.graphics.getWidth(), "center")
    end
end

function drawUI()
    -- UI layer in screen space
    -- HP Bar
    love.graphics.setColor(0.2, 0, 0)
    love.graphics.rectangle("fill", 10, 10, 200, 20)
    love.graphics.setColor(0, 1, 0)
    love.graphics.rectangle("fill", 10, 10, (hp / maxHp) * 200, 20)
    love.graphics.setColor(1, 1, 1)

    -- Power-up indicators
    if fireRateBoosts > 0 then
        love.graphics.print("Fire Rate Boosts: " .. fireRateBoosts, 10, 35)
    end
    if bulletSizeBoosts > 0 then
        love.graphics.print("Bullet Size Boosts: " .. bulletSizeBoosts, 10, 50)
    end
    if radarZoomBoosts > 0 then
        love.graphics.print("Radar Zoom Boosts: " .. radarZoomBoosts, 10, 65)
    end

    -- Radar
    local zoom = radarZoomBoosts == 0 and 1 or (1.333 + 0.1 * (radarZoomBoosts - 1))
    local radarRadius = 50 * zoom
    local scale = (50 / 1200) / zoom
    local offset = (zoom - 1) * 50
    local radarX = 70 + offset
    local radarY = love.graphics.getHeight() - 70 - offset
    love.graphics.setColor(1, 1, 1)
    love.graphics.circle("line", radarX, radarY, radarRadius)
    -- Player dot
    love.graphics.circle("fill", radarX, radarY, 3)
    -- Asteroid dots
    love.graphics.setColor(0.6, 0.6, 0.6)
    for _, ast in ipairs(asteroids) do
        local dx = (ast.x - shipX) * scale
        local dy = (ast.y - shipY) * scale
        local distSq = dx*dx + dy*dy
        if distSq <= radarRadius * radarRadius then
            love.graphics.circle("fill", radarX + dx, radarY + dy, 2)
        end
    end
    -- Enemy dots
    love.graphics.setColor(1, 0, 0)
    for _, enemy in ipairs(enemies) do
        local dx = (enemy.x - shipX) * scale
        local dy = (enemy.y - shipY) * scale
        local distSq = dx*dx + dy*dy
        if distSq <= radarRadius * radarRadius then
            love.graphics.circle("fill", radarX + dx, radarY + dy, 2)
        end
    end
    -- Power-up dots
    for _, pu in ipairs(powerups) do
        local dx = (pu.x - shipX) * scale
        local dy = (pu.y - shipY) * scale
        local distSq = dx*dx + dy*dy
        if distSq <= radarRadius * radarRadius then
            if pu.type == "fireRate" then
                love.graphics.setColor(1, 1, 0)
            elseif pu.type == "bulletSize" then
                love.graphics.setColor(1, 0, 0)
            elseif pu.type == "radarZoom" then
                love.graphics.setColor(0, 0, 1)
            end
            love.graphics.circle("fill", radarX + dx, radarY + dy, 2)
        end
    end
    -- Player bullet dots
    love.graphics.setColor(1, 1, 0)
    for _, bullet in ipairs(bullets) do
        local dx = (bullet.x - shipX) * scale
        local dy = (bullet.y - shipY) * scale
        local distSq = dx*dx + dy*dy
        if distSq <= radarRadius * radarRadius then
            love.graphics.circle("fill", radarX + dx, radarY + dy, 1)
        end
    end
    -- Enemy bullet dots
    love.graphics.setColor(1, 0.5, 0)
    for _, bullet in ipairs(enemyBullets) do
        local dx = (bullet.x - shipX) * scale
        local dy = (bullet.y - shipY) * scale
        local distSq = dx*dx + dy*dy
        if distSq <= radarRadius * radarRadius then
            love.graphics.circle("fill", radarX + dx, radarY + dy, 1)
        end
    end

    -- Arena border lines
    love.graphics.setColor(0.8, 0.8, 0.8)
    love.graphics.setLineWidth(1)
    -- Set stencil for clipping
    love.graphics.stencil(function() love.graphics.circle("fill", radarX, radarY, radarRadius) end, "replace", 1)
    love.graphics.setStencilTest("greater", 0)
    -- Left
    local dx1 = (arenaMinX - shipX) * scale
    local dy1 = (arenaMinY - shipY) * scale
    local dx2 = (arenaMinX - shipX) * scale
    local dy2 = (arenaMaxY - shipY) * scale
    love.graphics.line(radarX + dx1, radarY + dy1, radarX + dx2, radarY + dy2)
    -- Right
    dx1 = (arenaMaxX - shipX) * scale
    dy1 = (arenaMinY - shipY) * scale
    dx2 = (arenaMaxX - shipX) * scale
    dy2 = (arenaMaxY - shipY) * scale
    love.graphics.line(radarX + dx1, radarY + dy1, radarX + dx2, radarY + dy2)
    -- Bottom
    dx1 = (arenaMinX - shipX) * scale
    dy1 = (arenaMinY - shipY) * scale
    dx2 = (arenaMaxX - shipX) * scale
    dy2 = (arenaMinY - shipY) * scale
    love.graphics.line(radarX + dx1, radarY + dy1, radarX + dx2, radarY + dy2)
    -- Top
    dx1 = (arenaMinX - shipX) * scale
    dy1 = (arenaMaxY - shipY) * scale
    dx2 = (arenaMaxX - shipX) * scale
    dy2 = (arenaMaxY - shipY) * scale
    love.graphics.line(radarX + dx1, radarY + dy1, radarX + dx2, radarY + dy2)
    love.graphics.setStencilTest()

    -- Timer and High Score
    love.graphics.setColor(1, 1, 1)
    love.graphics.push()
    love.graphics.scale(1.5, 1.5)
    love.graphics.printf(string.format("Time: %.1f", gameTime), 0, 10 / 1.5, (love.graphics.getWidth() - 10) / 1.5, "right")
    love.graphics.printf(string.format("High Score: %.1f", highScore), 0, 40 / 1.5, (love.graphics.getWidth() - 10) / 1.5, "right")
    love.graphics.pop()
end
function love.keypressed(key)
    if key == "escape" then
        love.event.quit()
    end

    if gameState == "title" then
        if key == "r" then
            resetGame()
            gameState = "playing"
        end
    elseif gameState == "playing" then
        if key == "p" then
            gameState = "paused"
        end
    elseif gameState == "paused" then
        if key == "p" then
            gameState = "playing"
        end
    elseif gameState == "gameOver" then
        if key == "r" then
            resetGame()
            gameState = "playing"
        end
    end
end