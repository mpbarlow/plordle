import "CoreLibs/graphics"
import "CoreLibs/sprites"
import "CoreLibs/timer"

import "BoardSquare"
import "ActiveRing"
import "support"

local gfx <const> = playdate.graphics

local wordList <const> = import "words"

local boardOrigin <const>  = {x = 10, y = 10}
local squareSize <const>   = {width = 30, height = 30}
local squareMargin <const> = 5

local board <const> = {}
local activeSquare  = {row = 1, square = 1}

local function makeBoard()
    for row = 1, 6 do
        board[row] = {}

        for square = 1, 5 do
            local x = ((square - 1) * squareSize.width) + ((square - 1) * squareMargin) + boardOrigin.x
            local y = ((row - 1) * squareSize.height) + ((row - 1) * squareMargin) + boardOrigin.y

            board[row][square] = BoardSquare({x = x, y = y}, squareSize)
        end
    end
end

makeBoard()

local activeRing = ActiveRing(boardOrigin, squareSize, squareMargin)

local boardSquare = board[activeSquare.row][activeSquare.square]

function playdate.update()
    local change, acceleratedChange = playdate.getCrankChange()

    if (acceleratedChange ~= 0) then
        boardSquare:handleCranking(acceleratedChange)

    elseif (playdate.buttonJustPressed(playdate.kButtonUp)) then
        boardSquare:moveToPreviousLetter()

    elseif (playdate.buttonJustPressed(playdate.kButtonDown)) then
        boardSquare:moveToNextLetter()

    elseif (playdate.buttonJustPressed(playdate.kButtonLeft)) then
        activeSquare.square -= 1
        activeRing:moveTo(activeSquare.row, activeSquare.square)

    elseif (playdate.buttonJustPressed(playdate.kButtonRight)) then
        activeSquare.square += 1
        activeRing:moveTo(activeSquare.row, activeSquare.square)
    end

    for row = 1, activeSquare.row do
        for square = 1, 5 do
            board[row][square].inPlay = square <= activeSquare.square
            board[row][square]:update()
        end
    end

    gfx.sprite.update()

    playdate.timer.updateTimers()
    playdate.drawFPS(380, 225)

    boardSquare = board[activeSquare.row][activeSquare.square]
end
