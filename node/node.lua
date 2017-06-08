gl.setup(1280, 720)

node.alias("room")

local json = require "json"

--
-- global variables
--

local base_time = N.base_time or 0 -- captures start time of the node

local current_exam
local all_exams = {}
local day = 0
local exam_started = false


util.auto_loader(_G)

-- reload and save schedule into 'exams'
util.file_watch("schedule.json", function(content)
    print("reloading schedule")
    exams = json.decode(content)
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

-- receive time and day (via socket)
util.data_mapper{
    ["clock/set"] = function(time)
        base_time = tonumber(time) - sys.now()
        N.base_time = base_time
        check_next_exam()
        print("UPDATED TIME", base_time)
    end;
    ["clock/day"] = function(new_day)
        print("DAY", new_day)
        day = new_day
    end;
}

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

function check_next_exam()
    local now = get_now()
    local room_next = {}
    for idx, exam in ipairs(exams) do
        if rooms[exam.place] and not room_next[exam.place] and exam.unix_stop > now then
            room_next[exam.place] = exam
        end
    end

    for room, exam in pairs(room_next) do
        exam.lines = wrap("Group " .. exam.group, 30)
    end

    if room_next[saal] then
        current_exam = room_next[saal]
    else
        current_exam = nil
    end

    if current_exam ~= nil and current_exam.unix_start <= now then
      exam_started = true
    end

    all_exams = {}
    for room, exam in pairs(room_next) do
        if current_exam and room ~= current_exam.place then
            all_exams[#all_exams + 1] = exam
        end
    end
    table.sort(all_exams, function(a, b) 
        if a.unix_start < b.unix_start then
            return true
        elseif a.unix_start > b.unix_start then
            return false
        else
            return a.place < b.place
        end
    end)
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

check_next_exam()

function next_exam_soon()
  check_next_exam()
  if current_exam and current_exam.unix_start - get_now() < 4.0 * 60 then
    return true
  end
  return false
end

function calc_exam_showtime()
  check_next_exam()
  if next_exam_soon() then
    local delta = current_exam.unix_start - get_now()
    if delta < 1 then
      --return 10
      return current_exam.unix_stop - get_now()
    else
      --return 10
      return current_exam.unix_start - get_now()
    end
  end
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
        -- TODO: show seat plan for 20 minutes in case the delta to the next exam
        time = calc_exam_showtime;
        enabled = function()
          return true
        end;
        draw = function()
            if not current_exam then
                font:write(20, 150, "Upcoming Exam Slot", 80, 1,1,1,1)
                white:draw(0, 140, WIDTH, 240, 0.2)
                font:write(20, 330, "No more exam slots.", 50, 1,1,1,1)
            else
                local delta = current_exam.unix_start - get_now()
                if delta > 0 then
                    font:write(20, 150, "Upcoming Exam Slot", 80, 1,1,1,1)
                else
                    font:write(20, 150, "Exam in Progress", 80, 1,1,1,1)
                end
                white:draw(0, 140, WIDTH, 240, 0.2)

                font:write(20, 450, current_exam.start .. " - " .. current_exam.stop, 65, 1,1,1,1)
                if delta > 0 then
                    font:write(20, 520, string.format("in %d min", math.floor(delta/60)+1), 65, 1,1,1,0.8)
                end
                local delta_stop = current_exam.unix_stop - get_now()
                if delta_stop > 0 and delta < 0 then
                  font:write(20, 520, string.format("%d min left", math.floor(delta_stop/60)+1), 65, 1,1,1,0.8)
                end

                for idx, line in ipairs(current_exam.lines) do
                    if idx >= 5 then
                        break
                    end
                    font:write(20, 300 - 60 + 60 * idx, line, 100, 1,1,1,1)
                end
                for i, student in ipairs(current_exam.students) do
                    font:write(730+50, 215 + 40 * i, "TI" .. room.startid + i-1, 40, 0.85, 0.85, 0.0, 1.0)
                    font:write(840+50, 215 + 40 * i, "- " .. student, 40, 0.85, 0.85, 0.0, 1.0)
                end
            end
        end
    }, {
        time = exit_screen_time;
        enabled = function()
            return not next_exam_soon() and exam_started
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
            Overlay = _G[room.texture];
            Grid = trichter_grid;
            time = time/room.speed;
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
  -- draw an analog clock until 10min before the exam starts
  if (current_exam ~= nil and current_exam.unix_start - 10*60 >= get_now()) then
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
