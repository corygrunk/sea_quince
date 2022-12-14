-- sea quince
-- v0.1
-- visual sequins sequencer
--
-- enc1: change selected note
-- enc2: move left/right
-- enc3: move up/down
-- key1: shift
-- key2: add an alternative note
-- key3: delete an alternative note
-- shift + enc1: change mode notes/time
-- shift + enc2: change step size (notes mode only)
-- shift + enc3: change seq length

s = require('sequins')
engine.name = 'PolyPerc'
MusicUtil = require('musicutil')
tabutil = require('tabutil')

local scale_names = {}
local notes = {}

-- NOTE: seq must be a sequin of nested sequins (6 note limit)
-- local seq = s{s{1,4,6},s{4,12,4,16,4},s{6},s{9,3,4,0,2,9},s{11,4,14,16},s{9,11},s{0},s{4,6,7},s{11},s{16},s{0},s{1},s{1},s{1},s{1},s{1}}
local seq = s{s{1,4,9},s{0},s{6},s{9},s{11},s{4,16,4,6},s{1},s{1},s{1},s{1},s{0},s{1},s{1},s{1},s{1},s{1}}
local step_size = 1
local time = s{s{4},s{4},s{4},s{4},s{4},s{4},s{4},s{4},s{4}}
local clock_div = {1/8,1/4,1/3,1/2,1,2}
local clock_div_string = {'1/8','1/4','1/3','1/2','1/1','2/1'}
-- seq = s{s{1},s{2},s{3},s{4},s{5},s{6},s{7},s{8},s{9},s{10},s{11},s{12},s{13},s{14},s{15},s{16}}
local selected_x = 1
local selected_y = 1
local selected_time_x = 1
local selected_time_y = 1
local mode = 'notes' -- 'notes' or 'time'
local shift_func = false


function init()
  seq.length = 6
  time.length = 1
  data = seq()
  screen.level(15)
  screen.aa(0)
  screen.line_width(1)
  
  for i = 1, #MusicUtil.SCALES do
    table.insert(scale_names, MusicUtil.SCALES[i].name)
  end

  params:add_separator("sea quince")
  
  -- setting root notes using params
  params:add{type = "number", id = "root_note", name = "root note",
    min = 0, max = 127, default = 60, formatter = function(param) return MusicUtil.note_num_to_name(param:get(), true) end,
    action = function() build_scale() end} -- by employing build_scale() here, we update the scale

  -- setting scale type using params
  params:add{type = "option", id = "scale", name = "scale",
    options = scale_names, default = 5,
    action = function() build_scale() end} -- by employing build_scale() here, we update the scale

  -- setting how many notes from the scale can be played
  params:add{type = "number", id = "pool_size", name = "note pool size",
    min = 1, max = 20, default = 16,
    action = function() build_scale() end}

  build_scale() -- builds initial scale
  
  params:add_group("synth",6)
  cs_AMP = controlspec.new(0,1,'lin',0,0.5,'')
  params:add{type="control",id="amp",controlspec=cs_AMP,
    action=function(x) engine.amp(x) end}

  cs_PW = controlspec.new(0,100,'lin',0,50,'%')
  params:add{type="control",id="pw",controlspec=cs_PW,
    action=function(x) engine.pw(x/100) end}

  cs_REL = controlspec.new(0.1,3.2,'lin',0,1.2,'s')
  params:add{type="control",id="release",controlspec=cs_REL,
    action=function(x) engine.release(x) end}

  cs_CUT = controlspec.new(50,5000,'exp',0,800,'hz')
  params:add{type="control",id="cutoff",controlspec=cs_CUT,
    action=function(x) engine.cutoff(x) end}

  cs_GAIN = controlspec.new(0,4,'lin',0,1,'')
  params:add{type="control",id="gain",controlspec=cs_GAIN,
    action=function(x) engine.gain(x) end}
  
  cs_PAN = controlspec.new(-1,1, 'lin',0,0,'')
  params:add{type="control",id="pan",controlspec=cs_PAN,
    action=function(x) engine.pan(x) end}

  main_clock = clock.run(clock_tick)
end

function build_scale()
  notes = MusicUtil.generate_scale_of_length(params:get("root_note"), params:get("scale"), params:get("pool_size"))
  local num_to_add = 16 - #notes
  for i = 1, num_to_add do
    table.insert(notes, notes[16 - num_to_add])
  end
end


-- MAIN CLOCK
function clock_tick()
  while true do
    step()
  end
end

function update(position, table) -- adds a value to the end of the sequin
  seq[position]:settable(table)
end

function add(position, to_add)
  if seq[position].length < 6 then
    local temp_table = {}
    for i=1, seq[position].length do ----------------- recreate the existing table
      table.insert(temp_table, seq[position][i])
    end
    table.insert(temp_table, to_add)
    seq[position]:settable(temp_table)
  else
    print('Cannot add anymore values')
  end
end

function add_time(position, to_add)
  if time[position].length < 6 then
    local temp_table = {}
    for i=1, time[position].length do ----------------- recreate the existing table
      table.insert(temp_table, time[position][i])
    end
    table.insert(temp_table, to_add)
    time[position]:settable(temp_table)
  else
    print('Cannot add anymore values')
  end
end

function remove(position)
  if seq[position].length > 1 then
    local temp_table = {}
    for i=1, seq[position].length do ----------------- recreate the existing table
      table.insert(temp_table, seq[position][i])
    end
    table.remove(temp_table)
    seq[position]:settable(temp_table)
  else
    print('Nothing left to remove')
  end
end

function remove_time(position)
  if time[position].length > 1 then
    local temp_table = {}
    for i=1, time[position].length do ----------------- recreate the existing table
      table.insert(temp_table, time[position][i])
    end
    table.remove(temp_table)
    time[position]:settable(temp_table)
  else
    print('Nothing left to remove')
  end
end

-- EVERY CLOCK TICK
function step()
  local clk_div = time()
  -- had to do some wierd stuff here. should fix.
  -- had to move redraw() and call seq() in init.
  -- not ideal
  redraw()

  clock.sync(clock_div[clk_div])
  data = seq()

  if type(data) ~= 'table' and data ~= nil and data > 0 then
    local freq = MusicUtil.note_num_to_freq(notes[data])
    engine.hz(freq)
  end
end

-- SCREEN REDRAW
function redraw()
  screen.clear()
  screen.aa(0)

  if mode == 'notes' then
    screen.level(shift_func == true and 15 or 3)
    screen.move(0, 5)
    screen.text('Sea quince')
  
    screen.level(shift_func == true and 3 or 0)
    screen.move(113, 5)
    screen.text_right('step size:')
    
    screen.level(shift_func == true and 15 or 3)
    screen.move(125, 5)
    screen.text_right(step_size)
  
    for i=1, seq.length do
      local main_seq_ix = i -- number of column - seq.ix stored to use in nested 'for loop'
      local y = i*8 - 5
      screen.level(1)
  
      if type(seq[i]) == 'number' then -- single value
        print('seq must be a sequin of nested sequins: ex: s{s{1},s{2},s{3}}')
      else -- nested sequin
        for i=1, seq[i].length do
          screen.move(y, i*8 + 10)
          if seq.ix == main_seq_ix and i == seq[main_seq_ix].ix then
            screen.level(6)
          else
            screen.level(1)
          end
          if selected_x == main_seq_ix and selected_y == i then
            screen.level(15)
          end
          screen.text_center(seq[main_seq_ix][i] == 0 and '*' or seq[main_seq_ix][i])
        end
      end
   
      screen.move(i*8 - 7, 10)
      screen.level(i == seq.ix and 15 or 1)
      screen.line_rel(6,0)
      screen.stroke()
    end
  else -- time mode
    screen.level(shift_func == true and 15 or 3)
    screen.move(0, 5)
    screen.text('Time is imaginary')

    for i=1, time.length do
      local main_seq_ix = i -- number of column - time.ix stored to use in nested 'for loop'
      local y = i*16 - 15
      screen.level(1)
  
      if type(time[i]) == 'number' then -- single value
        print('time must be a sequin of nested sequins: ex: s{s{1},s{2},s{3}}')
      else -- nested sequin
        for i=1, time[i].length do
          screen.move(y, i*8 + 10)
          if time.ix == main_seq_ix and i == time[main_seq_ix].ix then
            screen.level(6)
          else
            screen.level(1)
          end
          if selected_time_x == main_seq_ix and selected_time_y == i then
            screen.level(15)
          end
          screen.text(time[main_seq_ix][i] == 0 and '*' or clock_div_string[time[main_seq_ix][i]])
        end
      end

      screen.move(i*16 - 16, 10)
      screen.level(i == time.ix and 15 or 1)
      screen.line_rel(15,0)
      screen.stroke()
    end
  end
  screen.update()
end


-- ENCODERS
function enc(n,z)
  if n==1 then
    if shift_func then
      -- change mode
      local test_mode = z < 0 and 'notes' or 'time'
      if mode ~= test_mode then
        mode = z < 0 and 'notes' or 'time'
      end
    elseif mode == 'notes' then
      -- change value
      seq[selected_x][selected_y] = util.clamp(seq[selected_x][selected_y] + z*1,0,params:get("pool_size"))
    else
      time[selected_time_x][selected_time_y] = util.clamp(time[selected_time_x][selected_time_y] + z*1,1,tabutil.count(clock_div))
    end
  elseif n==2 then
    if shift_func and mode == 'notes' then
      -- change notes sequence length
      seq.length = util.clamp(seq.length + z*1,1,16)
    elseif shift_func and mode == 'time' then
      -- change time sequence length
      time.length = util.clamp(time.length + z*1,1,8)
    elseif mode == 'notes' then
      -- navigate left and right
      local prev_selected_y = selected_y
      selected_x = util.clamp(selected_x + z*1,1,seq.length)
      if prev_selected_y > seq[selected_x].length then
        selected_y = seq[selected_x].length
      end
    else
      -- navigate left and right
      local prev_selected_time_y = selected_time_y
      selected_time_x = util.clamp(selected_time_x + z*1,1,time.length)
      if prev_selected_time_y > time[selected_time_x].length then
        selected_time_y = time[selected_time_x].length
      end
    end
  elseif n==3 then
    if shift_func and mode == 'notes' then
      -- change step interval
      local step_size_equation = math.floor(seq.length - 1) -- make something usable
      step_size = util.clamp(step_size + z*1,-1 * step_size_equation,step_size_equation)
      seq:step(step_size)
    elseif mode == 'notes' then
    -- navigate up and down
    selected_y = util.clamp(selected_y + z*1,1,seq[selected_x].length)
    else
      selected_time_y = util.clamp(selected_time_y + z*1,1,time[selected_time_x].length) 
    end
  end
  redraw()
end 

-- KEYS
function key(n,z)
  if n==1 then
    shift_func = z==1
  elseif n==2 and z==1 then
    if mode == 'notes' then
      -- add a nested note sequin
      local duplicate_prev_val = seq[selected_x][seq[selected_x].length]
      add(selected_x,duplicate_prev_val)
      selected_y = seq[selected_x].length
    else
      -- add a nested time sequin
      local duplicate_prev_val = time[selected_time_x][time[selected_time_x].length]
      add_time(selected_time_x,duplicate_prev_val)
      selected_time_y = time[selected_time_x].length
    end
  elseif n==3 and z==1 then
    if mode == 'notes' then
      -- delete last note value
      remove(selected_x)
      if selected_y > seq[selected_x].length then
        selected_y = seq[selected_x].length
      end
    else
      -- delete last time value
      remove_time(selected_time_x)
      if selected_time_y > time[selected_time_x].length then
        selected_time_y = time[selected_time_x].length
      end
    end
  end
  redraw()
end




-- UTILITY TO RESTART SCRIPT FROM MAIDEN
function r() -- shortcut
  rerun()
end
function rerun()
  norns.script.load(norns.state.script)
end
