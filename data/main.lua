-- 1. Комплексная математика
local complex = {}
function complex.new(r, i) return {r = r, i = i or 0} end
function complex.add(a, b) return {r = a.r + b.r, i = a.i + b.i} end
function complex.sub(a, b) return {r = a.r - b.r, i = a.i - b.i} end
function complex.mul(a, b) return {r = a.r * b.r - a.i * b.i, i = a.r * b.i + a.i * b.r} end
function complex.div(a, b)
  local den = b.r^2 + b.i^2
  return {r = (a.r * b.r + a.i * b.i) / den, i = (a.i * b.r - a.r * b.i) / den}
end
function complex.sqrt(a)
  local m = math.sqrt(a.r^2 + a.i^2)
  return {r = math.sqrt((m + a.r) / 2), i = (a.i >= 0 and 1 or -1) * math.sqrt((m - a.r) / 2)}
end
function complex.tanh(a)
  local den = math.cosh(2 * a.r) + math.cos(2 * a.i)
  return {r = math.sinh(2 * a.r) / den, i = math.sin(2 * a.i) / den}
end
function complex.abs(a) return math.sqrt(a.r^2 + a.i^2) end

-- 2. Физический расчет
-- В функцию добавлен аргумент h_table
local function get_reflection_db(freq_ghz, num_layers, h_table)
  local eps0, mu0 = 8.854e-12, 1.256e-6
  local Z0, c0 = math.sqrt(mu0 / eps0), 1 / math.sqrt(eps0 * mu0)
  local omega = 2 * math.pi * freq_ghz * 1e9
  
  -- Параметры h теперь берутся из h_table
  local layers = {
    {eps = complex.new(10, -3),  mu = complex.new(3, -0.0011), h = h_table[1] or 3e-3},
    {eps = complex.new(2, -1),   mu = complex.new(1, 0),       h = h_table[2] or 0.5e-3},
    {eps = complex.new(2, -0.3), mu = complex.new(1, 0),       h = h_table[3] or 0.5e-3}
  }
  
  local zin = complex.new(Z0, 0)
  for i = 1, num_layers do
    local L = layers[i]
    local zc = complex.sqrt(complex.div(complex.mul(complex.new(mu0), L.mu), complex.mul(complex.new(eps0), L.eps)))
    local gam_h = complex.mul(complex.new(0, omega * L.h / c0), complex.sqrt(complex.mul(L.mu, L.eps)))
    local th = complex.tanh(gam_h)
    zin = complex.mul(zc, complex.div(complex.add(zin, complex.mul(zc, th)), complex.add(zc, complex.mul(zin, th))))
  end
  local r = complex.div(complex.sub(zin, complex.new(Z0)), complex.add(zin, complex.new(Z0)))
  local val = complex.abs(r)
  if val < 1e-10 then val = 1e-10 end 
  return 20 * (math.log(val) / math.log(10))
end


-- ... (весь блок 'complex' и 'get_reflection_db' остается без изменений) ...

local graph_surf = sol.surface.create(800, 200)
local scroll_x = 0 -- Смещение прокрутки
local freq_range = 24 -- Ширина видимого диапазона ГГц

local function draw_plot()
  graph_surf:clear()
  graph_surf:fill_color({10, 10, 10}) 
  
  local w, h = graph_surf:get_size()
  local padding = 50
  local colors = {{255, 80, 80}, {80, 255, 80}, {80, 80, 255}}
  local labels = {"1 layer", "2 layers", "3 layers"}
  local values_start_end = {6e-3, 1e-3, 1e-3}

  local function draw_txt(str, tx, ty, col)
    local txt = sol.text_surface.create({text = str, font = "eng", font_size = 16})
    txt:set_color(col or {255, 255, 255})
    txt:draw(graph_surf, tx, ty)
  end

  -- Отрисовка сетки и меток (динамическая ось X)
  graph_surf:fill_color({150, 150, 150}, padding, h - padding, w - 2 * padding, 2)
  graph_surf:fill_color({150, 150, 150}, padding, padding, 2, h - 2 * padding)

  for i = 0, 4 do
    -- Ось Y (статична)
    local db_val = -10 * i
    local y = (h - padding) - ((db_val + 40) / 40) * (h - 2 * padding)
    graph_surf:fill_color({85, 85, 85}, padding, y, w - 2*padding, 1)
    draw_txt(tostring(db_val), padding - 25, y - 6)

    -- Ось X (зависит от scroll_x)
    local x = padding + (i / 4) * (w - 2 * padding)
    local ghz_label = math.floor(1 + scroll_x + (i / 4) * freq_range)
    draw_txt(tostring(ghz_label), x - 8, h - padding + 10)
  end

  -- Отрисовка графиков
  for layer_idx = 1, 3 do
    for i = 0, 400 do 
      -- Частота теперь зависит от scroll_x
      local f = 1 + scroll_x + (i / 400) * freq_range
      if f > 0 then
        local db = get_reflection_db(f, layer_idx, values_start_end)
        
        local x = padding + (i / 400) * (w - 2 * padding)
        local y = (h - padding) - ((db + 40) / 40) * (h - 2 * padding)
        
        if y >= padding and y <= h - padding then
          graph_surf:fill_color(colors[layer_idx], x, y, 2, 2)
        end
      end
    end
  end
  draw_txt("GHz (Arrows to scroll)", w - 180, h - padding + 30)
end

-- Обработка управления
function sol.main:on_key_pressed(key)
  local step = 1 -- Шаг прокрутки в ГГц
  if key == "right" then
    scroll_x = scroll_x + step
  elseif key == "left" then
    scroll_x = math.max(0, scroll_x - step) -- Ограничение, чтобы не уходить в минус
  end
  draw_plot()
end

function sol.main:on_started()
  draw_plot()
end

function sol.main:on_draw(screen)
  if graph_surf then graph_surf:draw(screen) end
end
