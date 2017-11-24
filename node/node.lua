gl.setup(1280, 720)

node.alias("room")

local json = require "json"

--
-- global variables
--

local base_time = N.base_time or 0 -- captures start time of the node

local current_exam = nil
local current_exam_idx = 0

local all_exams = {}
local day = 0


util.auto_loader(_G)

-- reload and save schedule into 'exams'
util.file_watch("schedule.json", function(content)
    print("reloading schedule")
    exams = json.decode(content)
    -- count exams
    numexams = 0
    for _ in pairs(exams) do numexams = numexams + 1 end
end)

-- reload and save config
util.file_watch("config.json", function(content)
    print("reloading config")
    local config = json.decode(content)
    if sys.get_env then
        saal = config.devices[sys.get_env("SERIAL")]
    end
    if not saal then
        print("using statically configured saal identifier")
        saal = config.saal
    end
    print(saal)
    rooms = config.rooms
    room = config.rooms[saal]
end)

-- receive data (via socket)
-- https://info-beamer.com/doc/info-beamer#node.event/data
util.data_mapper{
    -- time and day
    ["clock/set"] = function(time)
        base_time = tonumber(time) - sys.now()
        N.base_time = base_time
        print("UPDATED TIME", base_time)
    end;
    ["clock/day"] = function(new_day)
        print("DAY", new_day)
        day = new_day
    end;
    -- commands
    ["cmd"] = function(cmd)
        print("EXECUTE COMMAND", cmd)
        exec(cmd)
    end;
}

-- manage current exam/slot
function exec(cmd)
    -- define actions on each command
    -- http://lua-users.org/wiki/SwitchStatement
    local action = {
        ["forward"] =
            function()
                next_exam(1)
            end,
        ["backward"] =
            function()
                next_exam(-1)
            end,
        ["start"] =
            function()
                if current_exam ~= nil and current_exam.started == false then
                    print("start exam")
                    current_exam.unix_start = get_now()
                    current_exam.started = true
                end
            end,
        ["reset"] =
            function()
                apply_exam(nil)
            end,
    }
    -- execute
    action[cmd]()
end

-- returns current time as timestamp
function get_now()
    -- sys.now() gives the seconds from node start
    return base_time + sys.now()
end

-- returns current time as string
function get_now_str()
    local time = get_now() % 86400
    return string.format("%02d:%02d", math.floor(time / 3600), math.floor(time % 3600 / 60))
end

-- sets all variables to display the exam with given index
function apply_exam(idx)
    -- no exam
    if idx == nil or idx == 0 then
        print("show clock")
        current_exam = nil
        return
    end
    -- set a specific exam
    print("apply exam index " .. idx)
    current_exam = exams[current_exam_idx]
    current_exam.lines = wrap("Group " .. current_exam.group, 30)
    -- reset start variables
    current_exam.started = false
    current_exam.unix_start = nil
end

-- selects next exam by adding 'add' to the current index
function next_exam(add)
    print("select next +(" .. add.. ") exam")
    -- get next slot index for this room
    local r = nil
    while r ~= saal do
        current_exam_idx = current_exam_idx + (add)
        -- keep within borders
        if current_exam_idx < 1 then
            current_exam_idx = numexams
        elseif current_exam_idx > numexams then
            current_exam_idx = 1
        end
        -- check room of this index
        r = exams[current_exam_idx].place
    end
    -- save exam structure
    apply_exam(current_exam_idx)
end

function wrap(str, limit, indent, indent1)
    limit = limit or 72
    local here = 1
    local wrapped = str:gsub("(%s+)()(%S+)()", function(sp, st, word, fi)
        if fi-here > limit then
            here = st
            return "\n"..word
        end
    end)
    local splitted = {}
    for token in string.gmatch(wrapped, "[^\n]+") do
        splitted[#splitted + 1] = token
    end
    return splitted
end

function calc_exam_showtime()
    if current_exam ~= nil and current_exam.started then
        --return 10  -- for testing
        return current_exam.duration - (get_now() - current_exam.unix_start)
    end
    -- rotate screen as long no exam is started
    return 10
end

function exit_screen_time()
    return 28
end

function switcher(screens)
    local current_idx = 1
    local current = screens[current_idx]
    local switch = sys.now() + current.time()
    local switched = sys.now()

    local blend = 1.5

    local function draw()
        local now = sys.now()

        local percent = ((now - switched) / (switch - switched)) * 3.14129 * 2 - 3.14129
        progress:use{percent = percent}
        white:draw(WIDTH-50, HEIGHT-50, WIDTH-10, HEIGHT-10)
        progress:deactivate()

        if now - switched < blend then
            local delta = (switched - now) / blend
            gl.pushMatrix()
            gl.translate(WIDTH/2, 0)
            gl.rotate(270-90 * delta, 0, 1, 0)
            gl.translate(-WIDTH/2, 0)
            current.draw()
            gl.popMatrix()
        elseif now < switch - blend then
            current.draw(now - switched)
        elseif now < switch then
            local delta = 1 - (switch - now) / blend
            gl.pushMatrix()
            gl.translate(WIDTH/2, 0)
            gl.rotate(90 * delta, 0, 1, 0)
            gl.translate(-WIDTH/2, 0)
            current.draw()
            gl.popMatrix()
        else
            repeat
                current_idx = current_idx + 1
                if current_idx > #screens then
                    current_idx = 1
                end
            until screens[current_idx].enabled()
            current = screens[current_idx]
            switch = now + current.time()
            print ("switch in " .. (current.time()/60) .. " minutes")
            switched = now
        end
    end
    return {
        draw = draw;
    }
end

content = switcher{
    {
        time = calc_exam_showtime;
        enabled = function()
            return true
        end;
        draw = function()
            assert(current_exam ~= nil, "no exam loaded/selected")

            -- print status of exam
            if current_exam.started then
                font:write(20, 150, "Exam in Progress", 80, 1,1,1,1)
                -- print time left
                local min_to_go = math.floor( (current_exam.duration -
                    (get_now() - current_exam.unix_start))/60) + 1
                font:write(20, 520,
                           string.format("%d min left", min_to_go),
                           65, 1,1,1,0.8)
            else
                font:write(20, 150, "Upcoming Exam Slot", 80, 1,1,1,1)
            end
            white:draw(0, 140, WIDTH, 240, 0.2)

            -- print group information
            font:write(20, 300,
                       "Group " .. current_exam.group,
                       60, 1,1,1,1)

            -- print scheduled "start - stop" time
            font:write(20, 380,
                       current_exam.start .. " - " .. current_exam.stop,
                       60, 1,1,1,1)

            -- print PC number + student ID
            for i, student in ipairs(current_exam.students) do
                x = 480
                y = 215
                if i >= 12 then
                    x = 880
                    y = 215 - 40*14
                end
                font:write(x+50, y + 40 * i,
                           room.startid + i-1, 40, 0.85, 0.85, 0.0, 1.0)
                font:write(x+150, y + 40 * i,
                           "- " .. student, 40, 0.85, 0.85, 0.0, 1.0)
            end
        end
    }, {
        time = exit_screen_time;
        enabled = function()
            if current_exam ~= nil and current_exam.started then
                local seconds_to_go = current_exam.duration - (get_now() - current_exam.unix_start)
                return (seconds_to_go < 0)
            end
            return false
        end;
        draw = function()
            white:draw(0, 140, WIDTH, 240, 0.2)
            font:write(20, 150, "Exam Finished", 80, 1,1,1,1)
            font:write(20, HEIGHT/2-30, "Please leave the TILAB through the front glass door exit", 35,1,1,1,1)
            font:write(20, HEIGHT/2+30, "Bitte verlassen Sie das TILAB durch den Glastuerenausgang", 35, 1,1,1,1)
        end
       },
}

function hand(size, strength, angle, r,g,b,a)
    gl.pushMatrix()
    gl.translate(WIDTH/2, HEIGHT/2)
    gl.rotate(angle, 0, 0, 1)
    white:draw(0, -strength, size, strength)
    gl.popMatrix()
end

local bg

function draw_clock()
    if not bg then
        gl.pushMatrix()
        gl.translate(WIDTH/2, HEIGHT/2)
        for i = 0, 59 do
            gl.pushMatrix()
            gl.rotate(360/60*i, 0, 0, 1)
            if i % 15 == 0 then
                white:draw(HEIGHT/2.1-80, -10, HEIGHT/2.1, 10, 0.8)
            elseif i % 5 == 0 then
                white:draw(HEIGHT/2.1-50, -10, HEIGHT/2.1, 10, 0.5)
            else
                white:draw(HEIGHT/2.1-5, -5, HEIGHT/2.1, 5, 0.5)
            end
            gl.popMatrix()
        end
        gl.popMatrix()
        bg = resource.create_snapshot()
    else
        bg:draw(0,0,WIDTH,HEIGHT)
    end

    local time = get_now()

    local hour = (time / 3600) % 12
    local minute = time % 3600 / 60
    local second = time % 60

    local fake_second = second * 1.01
    if fake_second >= 60 then
        fake_second = 60
    end

    hand(HEIGHT/4,   10, 360/12 * hour - 90)
    hand(HEIGHT/2.5, 5, 360/60 * minute - 90)
    hand(HEIGHT/2.1,  2, 360/60 * (((math.sin((fake_second-0.4) * math.pi*2)+1)/8) + fake_second) - 90)
    dot:draw(WIDTH/2-30, HEIGHT/2-30, WIDTH/2+30, HEIGHT/2+30)
end;

vortex = (function()
    local function draw()
        local time = sys.now()
        trichter:use{
            Overlay = _G["marble"];
            Grid = trichter_grid;
            time = time/100;
        }
        trichter_map:draw(-850, 0, WIDTH+150, HEIGHT)
        trichter:deactivate()
    end
    return {
        draw = draw;
    }
end)()

function node.render()
    vortex.draw()
    if base_time == 0 then
        return
    end
    -- draw an analog clock if no exam selected
    if current_exam == nil then
        black:draw(0, 0, WIDTH, HEIGHT, 0.7)
        draw_clock()
    else
        util.draw_correct(logo, -30, 20, 320, 140)
        --util.draw_correct(tusignet, 20, 20, 2400, 120)
        font:write(390, 10, saal, 125, 1,1,1,1)
        font:write(870, 10, get_now_str(), 125, 1,1,1,1)
        --font:write(WIDTH-300, 20, string.format("Day %d", day), 100, 1,1,1,1)

        local fov = math.atan2(HEIGHT, WIDTH*2) * 360 / math.pi
        gl.perspective(fov, WIDTH/2, HEIGHT/2, -WIDTH,
                       WIDTH/2, HEIGHT/2, 0)

        content.draw()
    end
end
