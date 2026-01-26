# LÖVE 2D Project Instructions

## Architecture Overview
This is a simple LÖVE 2D game/demo with a single-entry point structure. All game logic resides in `main.lua`, utilizing LÖVE's callback system for initialization, updates, rendering, and input handling.

## Key Components
- **main.lua**: Contains all game code with standard LÖVE callbacks (`love.load`, `love.update`, `love.draw`, `love.keypressed`)
- Global variables for game state (e.g., `x`, `y`, `speed`) - keep simple and avoid complex state management

## Development Workflow
- **Run the game**: Use `love --console .` from project root for console output (useful for debugging prints)
- **Window setup**: Configured for 1366x768 with resizable=true; rendering scales to fit current window size
- **Debugging**: Add `print()` statements in callbacks; console output visible when run with `--console`

## Coding Patterns
- **Initialization**: Place setup code in `love.load()` (e.g., window mode, initial positions)
- **Game loop**: Update logic in `love.update(dt)` using delta time for smooth movement
- **Rendering**: Draw in `love.draw()`; use `love.graphics.push/pop()` for transformations like scaling
- **Input handling**: Check continuous input in `love.update()` (e.g., `love.keyboard.isDown()`); discrete events in `love.keypressed()`
- **Scaling**: Apply uniform scaling in draw: `love.graphics.scale(love.graphics.getWidth() / 1366, love.graphics.getHeight() / 768)` to maintain aspect ratio

## Examples
- Movement: `x = x + (speed * dt)` for smooth, frame-rate independent motion
- Quit: `if key == "escape" then love.event.quit() end` in `love.keypressed()`
- Drawing: `love.graphics.circle("fill", x, y, 50)` for simple shapes

## Dependencies
- Requires LÖVE 2D framework installed
- No external Lua libraries; uses built-in LÖVE APIs only

## File Structure
- Keep everything in root; no subdirectories needed for simple projects
- Single `main.lua` file for all code</content>
<parameter name="filePath">/home/kubicekvojtech1/Git Projects/L-ve2Dtest/.github/copilot-instructions.md