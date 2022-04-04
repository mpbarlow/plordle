import "CoreLibs/object"
import "support"
import "Piece"
import "checkEntry"

local gfx <const> = playdate.graphics

local wordList <const> = import "words"

-- The number of milliseconds to wait between checking each letter when submitting a word.
local checkDuration <const> = 400

-- Build the board as a letterCount x guessCount grid of Pieces.
local function createBoard()
    local board = {}

    for row = 1, guessCount do
        board[row] = {}

        for position = 1, letterCount do
            local x = ((position - 1) * pieceSize.width) + ((position - 1) * pieceMargin) + boardOrigin.x
            local y = ((row - 1) * pieceSize.height) + ((row - 1) * pieceMargin) + boardOrigin.y

            board[row][position] = Piece({x = x, y = y}, pieceSize)
        end
    end

    return board
end

class('Game', {
    -- Set default event listeners so we don't have to check if they're defined before firing them.
    listeners = {
        [kEventGameStateDidTransition] = function () end,
        [kEventGameWon] = function () end,
        [kEventGameLost] = function () end,
    },
    -- We begin the game entering a word.
    state = kGameStateEnteringWord
}).extends()

function Game:init(word)
    Game.super.init(self)

    local board <const> = createBoard()

    local currentRow = 1
    local currentPosition = 1

    local function getCurrentRow(self)
        return currentRow
    end

    local function getCurrentPosition(self)
        return currentPosition
    end

    -- Update game and piece state based on the contents of wordCheckResults.
    local function handleEntryCheck(wordCheckResults)
        -- If the word was not in the list, emit an event and move back to entry mode.
        if wordCheckResults.state == kWordStateNotInList then
            self.listeners[kEventEnteredWordNotInList](self)
            self:transitionTo(kGameStateEnteringWord)

        -- Otherwise, update each piece's state to match the results. We update each piece a
        -- certain time after the last, to give the appearance of checking letter by letter.
        else
            for position = 1, letterCount do
                local piece = board[currentRow][position]
                local state = wordCheckResults.letters[position]

                playdate.timer.performAfterDelay((position - 1) * checkDuration, function ()
                    piece:setPieceState(state)
                end)
            end

            -- After all the pieces have animated, move to the next row and reset back into word
            -- entry mode. Waiting an extra half beat just feels better for some reason.
            playdate.timer.performAfterDelay(
                (letterCount * checkDuration) + (checkDuration / 2),
                function ()
                    -- If the word was correct, the player won.
                    if wordCheckResults.state == kWordStateCorrect then
                        self.listeners[kEventGameWon](self)
                        self:transitionTo(kGameStateWon)

                        return
                    end

                    -- If it wasn't correct and the player used all their guesses, they lost.
                    if currentRow == guessCount then
                        self.listeners[kEventGameLost](self)
                        self:transitionTo(kGameStateLost)

                        return
                    end

                    -- Otherwise move onto the next row and switch back to word entry mode.
                    currentRow += 1
                    currentPosition = 1

                    self:transitionTo(kGameStateEnteringWord)
                end
            )
        end
    end

    -- Returns the entered word on the current row of the board (in lowercase).
    local function getEnteredWord()
        local word = ""

        for i = 1, letterCount do
            word = word .. board[currentRow][i]:getLetter():lower()
        end

        return word
    end

    -- Perform a state transition to newState.
    local function transitionTo(self, newState)
        -- Update our state and call the event listener for a state transition to allow stuff
        -- outside of the core game logic to react (e.g. displaying a modal).
        self.state = newState
        self.listeners[kEventGameStateDidTransition](self, newState)

        -- If we've moved into the entry check state, check the input and update the game and piece
        -- state accordingly.
        if newState == kGameStateCheckingEntry then
            handleEntryCheck(checkEntry(getEnteredWord(), word, wordList))
        end
    end

    local function handleCranking(self, acceleratedChange)
        board[currentRow][currentPosition]:handleCranking(acceleratedChange)
    end

    local function moveLetter(self, steps)
        board[currentRow][currentPosition]:moveLetter(steps)
    end

    local function movePosition(self, steps)
        currentPosition += steps
    end

    -- Update the board piece at the given (row, position) co-ordinate.
    local function updatePieceAt(row, position)
        local pieceShouldBeInPlay = row < currentRow or position <= currentPosition

        -- When first adding a piece to play, set its initial letter to the last selected letter,
        -- rather than making the player go from "A" every time.
        -- TODO: Make this a game setting.
        if position > 1 and not board[row][position].inPlay and pieceShouldBeInPlay then
            board[row][position]:setLetter(board[row][position - 1]:getLetter())
        end

        board[row][position].inPlay = pieceShouldBeInPlay
        board[row][position]:update()
    end

    -- Update the pieces in play or that have previously been in play.
    local function updatePieces(self)
        for row = 1, currentRow do
            for position = 1, letterCount do
                updatePieceAt(row, position)
            end
        end
    end

    self.getCurrentRow = getCurrentRow
    self.getCurrentPosition = getCurrentPosition
    self.transitionTo = transitionTo
    self.handleCranking = handleCranking
    self.moveLetter = moveLetter
    self.movePosition = movePosition
    self.updatePieces = updatePieces
end
