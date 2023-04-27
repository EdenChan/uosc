local Element = require('uosc_shared/elements/Element')

---@alias TopBarButtonProps {icon: string; background: string; anchor_id?: string; command: string|fun(); hide_when_not_in_fullscreen: boolean; tooltip: string; hold: boolean;}

---@class TopBarButton : Element
local TopBarButton = class(Element)

---@param id string
---@param props TopBarButtonProps
function TopBarButton:new(id, props) return Class.new(self, id, props) --[[@as TopBarButton]] end
function TopBarButton:init(id, props)
	Element.init(self, id, props)
	self.anchor_id = 'top_bar'
	self.icon = props.icon
	self.background = props.background
	self.command = props.command
	self.hide_when_not_in_fullscreen = props.hide_when_not_in_fullscreen and true or false
	self.tooltip = props.tooltip
	self.hold = props.hold and true or false
end

function TopBarButton:on_mbtn_left_down()
	mp.command(type(self.command) == 'function' and self.command() or self.command)

	if self.hold then
		-- 按下左键，设置长按定时器，进行自动累加/重做
		set_press_and_hold_timer(function()
			mp.command(type(self.command) == 'function' and self.command() or self.command)
		end)
	end
end

function TopBarButton:on_mbtn_left_up()
	-- 抬起左键，清除长按定时器，取消自动累加
	unset_press_and_hold_timer()
end

function TopBarButton:render()
	local visibility = self:get_visibility()
	if visibility <= 0 then return end
	local ass = assdraw.ass_new()

	-- Background on hover
	if self.proximity_raw == 0 then
		-- ass:rect(self.ax, self.ay, self.bx, self.by, {color = self.background, opacity = visibility})
		local rev_bg = "cccccc"
		local cur_opacity = 0.6
		if self.background == "e81123" then
			rev_bg, cur_opacity = serialize_rgba(self.background).color, visibility
		end
		ass:rect(self.ax, self.ay, self.bx, self.by, {color = rev_bg, opacity = cur_opacity})
		if self.tooltip then
			ass:tooltip(self, self.tooltip)
		end
	else
		-- 此处将 rrggbb 颜色转成 ass:rect 方法所需的 bbggrr 序列，以统一颜色设置
		rev_bg = serialize_rgba(self.background).color
		ass:rect(self.ax, self.ay, self.bx, self.by, {color = rev_bg, opacity = 0.6})
	end

	local width, height = self.bx - self.ax, self.by - self.ay
	local icon_size = math.min(width, height) * 0.5
	ass:icon(self.ax + width / 2, self.ay + height / 2, icon_size, self.icon, {
		opacity = visibility, border = options.text_border, blur=20
	})

	return ass
end

--[[ TopBar ]]

---@class TopBar : Element
local TopBar = class(Element)

function TopBar:new() return Class.new(self) --[[@as TopBar]] end
function TopBar:init()
	Element.init(self, 'top_bar')
	self.size, self.size_max, self.size_min = 0, 0, 0
	self.icon_size, self.spacing, self.font_size, self.title_bx = 1, 1, 1, 1
	self.size_min_override = options.timeline_start_hidden and 0 or nil
	self.top_border = options.timeline_border
	self.show_alt_title = false
	self.main_title, self.alt_title = nil, nil

	local function get_maximized_command()
		return state.border
			and (state.fullscreen and 'set fullscreen no;cycle window-maximized' or 'cycle window-maximized')
			or 'set window-maximized no;cycle fullscreen'
	end

	-- Order aligns from right to left
	-- hide_when_not_in_fullscreen 选项仅可在没有设置 no-border 的情况下启用
	self.buttons = {
		-- TopBarButton:new('tb_close', {icon = 'close', background = '2311e8', command = 'quit', hide_when_not_in_fullscreen = false}),
		-- 反转 bbggrr 顺序
		TopBarButton:new('tb_close', {icon = 'close', background = 'e81123', command = 'quit', hide_when_not_in_fullscreen = false}),
		TopBarButton:new('tb_max', {icon = 'crop_square', background = options.background, command = get_maximized_command, hide_when_not_in_fullscreen = false}),
		TopBarButton:new('tb_min', {icon = 'minimize', background = options.background, command = 'cycle window-minimized', hide_when_not_in_fullscreen = false}),
		-- TopBarButton:new('tb_fullscreen', {icon = 'fullscreen', background = options.background, command = 'cycle fullscreen'}),
		TopBarButton:new('tb_zoom_reset', {icon = 'autorenew', background = options.background, command = 'set video-zoom 0;set video-pan-y 0;set video-pan-x 0;set contrast 0;set brightness 0;set gamma 0;set saturation 0', tooltip = '重置画面'}),
		TopBarButton:new('tb_move_right', {icon = 'keyboard_arrow_right', background = options.background, command = 'add video-pan-x -0.02', tooltip = '镜头右移', hold = true}),
		TopBarButton:new('tb_move_left', {icon = 'keyboard_arrow_left', background = options.background, command = 'add video-pan-x 0.02', tooltip = '镜头左移', hold = true}),
		TopBarButton:new('tb_move_down', {icon = 'keyboard_arrow_down', background = options.background, command = 'add video-pan-y -0.02', tooltip = '镜头下移', hold = true}),
		TopBarButton:new('tb_move_up', {icon = 'keyboard_arrow_up', background = options.background, command = 'add video-pan-y 0.02', tooltip = '镜头上移', hold = true}),
		TopBarButton:new('tb_zoom_out', {icon = 'zoom_out', background = options.background, command = 'add video-zoom -0.1', tooltip = '缩小', hold = true}),
		TopBarButton:new('tb_zoom_in', {icon = 'zoom_in', background = options.background, command = 'add video-zoom 0.1', tooltip = '放大', hold = true}),
	}

	self:decide_titles()
end

function TopBar:decide_enabled()
	if options.top_bar == 'no-border' then
		self.enabled = not state.border or state.fullscreen
	else
		self.enabled = options.top_bar == 'always'
	end
	self.enabled = self.enabled and (options.top_bar_controls or options.top_bar_title)
	for _, element in ipairs(self.buttons) do
		hide_in_screen = element.hide_when_not_in_fullscreen and not state.fullscreen
		element.enabled = self.enabled and options.top_bar_controls and not hide_in_screen
	end
end

function TopBar:decide_titles()
	self.alt_title = state.alt_title ~= '' and state.alt_title or nil
	self.main_title = state.title ~= '' and state.title or nil

	-- Fall back to alt title if main is empty
	if not self.main_title then
		self.main_title, self.alt_title = self.alt_title, nil
	end

	-- Deduplicate the main and alt titles by checking if one completely
	-- contains the other, and using only the longer one.
	if self.main_title and self.alt_title and not self.show_alt_title then
		local longer_title, shorter_title
		if #self.main_title < #self.alt_title then
			longer_title, shorter_title = self.alt_title, self.main_title
		else
			longer_title, shorter_title = self.main_title, self.alt_title
		end

		local escaped_shorter_title = string.gsub(shorter_title --[[@as string]], "[%(%)%.%+%-%*%?%[%]%^%$%%]", "%%%1")
		if string.match(longer_title --[[@as string]], escaped_shorter_title) then
			self.main_title, self.alt_title = longer_title, nil
		end
	end
end

function TopBar:update_dimensions()
	self.size = state.fullormaxed and options.top_bar_size_fullscreen or options.top_bar_size
	self.icon_size = round(self.size * 0.5)
	self.spacing = math.ceil(self.size * 0.25)
	self.font_size = math.floor((self.size - (self.spacing * 2)) * options.font_scale)
	self.button_width = round(self.size * 1.15)
	self.ay = Elements.window_border.size
	self.bx = display.width - Elements.window_border.size
	self.by = self.size + Elements.window_border.size
	-- self.title_bx = self.bx - (options.top_bar_controls and (self.button_width * 3) or 0)
	self.title_bx = self.bx - (options.top_bar_controls and (self.button_width * #self.buttons) or 0)
	self.ax = options.top_bar_title and Elements.window_border.size or self.title_bx

	local button_bx = self.bx
	for _, element in pairs(self.buttons) do
		if element.enabled then
			element.ax, element.bx = button_bx - self.button_width, button_bx
			element.ay, element.by = self.ay, self.by
			button_bx = button_bx - self.button_width
		end
	end
end

function TopBar:toggle_title()
	if options.top_bar_alt_title_place ~= 'toggle' then return end
	self.show_alt_title = not self.show_alt_title
end

function TopBar:on_prop_title() self:decide_titles() end
function TopBar:on_prop_alt_title() self:decide_titles() end

function TopBar:on_prop_border()
	self:decide_enabled()
	self:update_dimensions()
end

function TopBar:on_prop_fullscreen()
	self:decide_enabled()
	self:update_dimensions()
end

function TopBar:on_prop_maximized()
	self:decide_enabled()
	self:update_dimensions()
end

function TopBar:on_mbtn_left_down()
	if cursor.x < self.title_bx then self:toggle_title() end
end

function TopBar:on_display() self:update_dimensions() end

function TopBar:render()
	local visibility = self:get_visibility()
	if visibility <= 0 then return end
	local ass = assdraw.ass_new()

	-- Window title
	if options.top_bar_title and (state.title or state.has_playlist) then
		local bg_margin = math.floor((self.size - self.font_size) / 4)
		local padding = self.font_size / 2
		local title_ax = self.ax + bg_margin
		local title_ay = self.ay + bg_margin
		local max_bx = self.title_bx - self.spacing

		-- Playlist position
		if state.has_playlist then
			local text = state.playlist_pos .. '' .. state.playlist_count
			local formatted_text = '{\\b1}' .. state.playlist_pos .. '{\\b0\\fs' .. self.font_size * 0.9 .. '}/'
				.. state.playlist_count
			local opts = {size = self.font_size, wrap = 2, color = fgt, opacity = visibility}
			local bx = round(title_ax + text_width(text, opts) + padding * 2)
			ass:rect(title_ax, title_ay, bx, self.by - bg_margin, {color = fg, opacity = visibility, radius = 2})
			ass:txt(title_ax + (bx - title_ax) / 2, self.ay + (self.size / 2), 5, formatted_text, opts)
			title_ax = bx + bg_margin
		end

		-- Skip rendering titles if there's not enough horizontal space
		if max_bx - title_ax > self.font_size * 3 then
			-- Main title
			local main_title = self.show_alt_title and self.alt_title or self.main_title
			if main_title then
				local opts = {
					size = self.font_size, wrap = 2, color = bgt, border = 1, border_color = "202331", opacity = visibility,
					clip = string.format('\\clip(%d, %d, %d, %d)', self.ax, self.ay, max_bx, self.by),
				}
				local bx = math.min(max_bx, title_ax + text_width(main_title, opts) + padding * 2)
				local by = self.by - bg_margin
				ass:rect(title_ax, title_ay, bx, by, {
					color = bg, opacity = visibility * options.top_bar_title_opacity, radius = 2,
				})
				ass:txt(title_ax + padding, self.ay + (self.size / 2), 4, main_title, opts)
				title_ay = by + 1
			end

			-- Alt title
			if self.alt_title and options.top_bar_alt_title_place == 'below' then
				local font_size = self.font_size * 0.9
				local height = font_size * 1.3
				local by = title_ay + height
				local opts = {
					size = font_size, wrap = 2, color = bgt, border = 1, border_color = "202331", opacity = visibility
				}
				local bx = math.min(max_bx, title_ax + text_width(self.alt_title, opts) + padding * 2)
				opts.clip = string.format('\\clip(%d, %d, %d, %d)', title_ax, title_ay, bx, by)
				ass:rect(title_ax, title_ay, bx, by, {
					color = bg, opacity = visibility * options.top_bar_title_opacity, radius = 2,
				})
				ass:txt(title_ax + padding, title_ay + height / 2, 4, self.alt_title, opts)
				title_ay = by + 1
			end

			-- Subtitle: current chapter
			if state.current_chapter then
				local font_size = self.font_size * 0.8
				local height = font_size * 1.3
				local text = '└ ' .. state.current_chapter.index .. ': ' .. state.current_chapter.title
				local by = title_ay + height
				local opts = {
					size = font_size, italic = true, wrap = 2, color = bgt,
					border = 1, border_color = "202331", opacity = visibility * 0.8,
				}
				local bx = math.min(max_bx, title_ax + text_width(text, opts) + padding * 2)
				opts.clip = string.format('\\clip(%d, %d, %d, %d)', title_ax, title_ay, bx, by)
				ass:rect(title_ax, title_ay, bx, by, {
					color = bg, opacity = visibility * options.top_bar_title_opacity, radius = 2,
				})
				ass:txt(title_ax + padding, title_ay + height / 2, 4, text, opts)
			end
		end
	end

	return ass
end

return TopBar
