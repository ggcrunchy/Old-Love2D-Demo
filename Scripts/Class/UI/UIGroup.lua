-- See TacoShell Copyright Notice in main folder of distribution

-- Standard library imports --
local assert = assert
local ipairs = ipairs
local type = type

-- Imports --
local Identity = funcops.Identity
local IsCallable = varops.IsCallable
local New = class.New
local NoOp = funcops.NoOp
local SetLocalRect = widgetops.SetLocalRect
local SuperCons = class.SuperCons
local WithResource = funcops.WithResource
local Weak = table_ex.Weak

-- Unique member keys --
local _alert_streams = {}
local _choice = {}
local _deferred = {}
local _entered = {}
local _grabbed = {}
local _mode = {}
local _root = {}

-- UIGroup class definition --
class.Define("UIGroup", function(UIGroup)
	--- Indicates whether the group is in an execute call, i.e. its mode is <b>"testing"</b>
	-- or <b>"issuing_events"</b>.
	-- @return If true, group is executing.
	-- @see UIGroup:Execute
	-- @see UIGroup:GetMode
	function UIGroup:IsExecuting ()
        local mode = self[_mode]

		return mode == "testing" or mode == "issuing_events"
	end

	--- Indicates whether the group is running in a callback, i.e. its mode is <b>
	-- "rendering"</b>, <b>"testing"</b>, or <b>"updating"</b>.
	-- @return If true, group is running callbacks.
	-- @see UIGroup:GetMode
	function UIGroup:IsRunningCallbacks ()
        local mode = self[_mode]

		return mode == "rendering" or mode == "testing" or mode == "updating"
	end

	-- Cache methods for internal use.
    local IsExecuting = UIGroup.IsExecuting

	-- Adds a task to call after callbacks / event issues
	-- task: Task to add
	function UIGroup:AddDeferredTask (task)
		-- In a callback or event issue, append the task.
		if self[_mode] then
			self[_deferred][#self[_deferred] + 1] = task
 
		-- Otherwise, call it immediately.
		else
			task()
		end
	end

	-- Adds a listener task for a signal
	-- slot: Signal slot
	-- task: Listener task routine
	-------------------------------------
	function UIGroup:AddListenerTask (slot, task)
		local stream = self[_alert_streams][slot]

		if not stream then
			stream = New("Stream")

			self[_alert_streams][slot] = stream
		end

		stream:Add(task)
	end

	--- Accessor.
	-- @return Reference to chosen widget, or <b>nil</b> if absent.
	function UIGroup:GetChoice ()
		return self[_choice]
	end

	--- Accessor.
	-- @return Reference to entered widget, or <b>nil</b> if absent.
	function UIGroup:GetEntered ()
		return self[_entered]
	end

	--- Accessor.
	-- @return Reference to grabbed widget, or <b>nil</b> if absent.
	function UIGroup:GetGrabbed ()
		return self[_grabbed]
	end

	--- Accessor.
	-- @return Current mode, which is one of: <b>"normal"</b>, <b>"rendering"</b>, <b>
	-- "testing"</b>, <b>"updating"</b>, or <b>"issuing_events"</b>.
	function UIGroup:GetMode ()
		return self[_mode] or "normal"
	end

    --- Accessor.
	-- @return Reference to root widget.
    function UIGroup:GetRoot ()
        return self[_root]
    end

    -- Resource usage
    -- G: Group handle
    -- action: Mode action
    -- mode: Group mode
    -- ...: Usage arguments
    local function Use (G, action, mode, ...)
        assert(not G[_mode], "Callbacks forbidden from other callbacks or event issues")

        -- Freshen the deferred list if necessary.
        local deferred = G[_deferred]

        if not deferred or #deferred > 0 then
            G[_deferred] = {}
        end

        -- Enter the callback mode.
        G[_mode] = mode

        -- Perform the mode action.
        action(G, ...)
    end

    -- Resource release
    -- G: Group handle
    local function Release (G)
        G[_mode] = nil
    end

    -- Performs a mode action
    -- G: Group handle
    -- action: Mode action
    -- mode: Group mode
    -- ...: Action arguments
    local function Action (G, action, mode, ...)
        WithResource(nil, Use, Release, G, action, mode, ...)

        -- Perform any deferred actions.
        for _, func in ipairs(G[_deferred]) do
            func()
        end
    end

    -- Execute --
    do
        -- Signals a widget and alerts signal listeners
        -- G: Group handle
        -- widget: Widget handle
        -- slot: Signal slot
        -- state: Execution state
        local function Alert (G, widget, slot, state)
            widget:Signal(slot, state)

            -- Alert any listeners.
            ;(G[_alert_streams][slot] or NoOp)(state)
        end

        -- G: Group handle
        -- state: Execution state; nil during a clear
        local function Abandon (G, state)
            Alert(G, G[_choice], "abandon", state)

            G[_choice] = nil
        end

        -- G: Group handle
        -- state: Execution state; nil during a clear
        local function Drop (G, state)
            Alert(G, G[_grabbed], "drop", state)

            G[_grabbed] = nil
        end

        -- G: Group handle
        -- state: Execution state
        local function EnterGrab (G, state)
            if G[_entered] ~= G[_choice] then
                G[_entered] = G[_choice]

                Alert(G, G[_entered], "enter", state)
            end

            -- On a press, do grab logic.
            if state("is_pressed") and not G[_grabbed] then
                G[_grabbed] = G[_choice]

                Alert(G, G[_grabbed], "grab", state)
            end
        end

        -- G: Group handle
        -- state: Execution state; nil during a clear
        local function Leave (G, state)
            Alert(G, G[_entered], "leave", state)

            G[_entered] = nil
        end

        --- Clears the group state. Cannot be called during execution.<br><br>
        -- Each of the following is cleared, if set, in this order: the entered widget, the
		-- grabbed widget, and the choice widget. Also, each widget thus cleared is sent a
		-- signal, in that same order, as<br><br>
        -- &nbsp&nbsp&nbsp<i><b>signal(W)</b></i>,<br><br>
        -- where <i>signal</i> is <b>leave</b>, <b>drop</b>, or <b>abandon</b> respectively,
		-- and <i>W</i> is the widget.<br><br>
		-- Any listeners to these signals are alerted.<br><br>
		-- Note that during a clear, the execution state parameter that would otherwise
		-- accompany these signals is <b>nil</b>.
        function UIGroup:Clear ()
            assert(not IsExecuting(self), "Clearing input forbidden during execution")

            -- Alert any special widgets about the clear.
            if self[_entered] then
                Leave(self)
            end

            if self[_grabbed] then
                Drop(self)
            end

            if self[_choice] then
                Abandon(self)
            end
        end

        -- Issues events to the choice and/or candidate
        -- G: Group handle
        -- candidate: Candidate handle
        -- state: Execution state
        local function IssueEvents (G, candidate, state)
            G[_mode] = "issuing_events"

            -- If there is a choice, perform upkeep on it.
            local choice = G[_choice]

            if choice then
                -- Pre-process the widget.
                Alert(G, choice, "enter_upkeep", state)

                -- Perform leave logic.
                if G[_entered] and G[_entered] ~= candidate then
                    Leave(G, state)
                end

                -- If the widget is the candidate, perform enter/grab logic.
                if candidate == choice then
                    EnterGrab(G, state)
                end

                -- If there is no press, perform drop logic.
                if not state("is_pressed") and G[_grabbed] then
                    Drop(G, state)
                end

                -- If the widget remains chosen, post-process it; otherwise, abandon it.
                if candidate ~= choice and G:GetGrabbed() ~= choice then
                    Abandon(G, state)

                else
                    Alert(G, choice, "leave_upkeep", state)
                end
            end

            -- If there is a candidate but no choice, choose it.
            if candidate and not G[_choice] then
                G[_choice] = candidate

                -- Pre-process the widget.
                Alert(G, candidate, "enter_choose", state)

                -- Perform enter/grab logic.
                EnterGrab(G, state)

                -- Post-process the widget.
                Alert(G, candidate, "leave_choose", state)
            end
        end

        -- Runs a test on the widget and through its attach list
        -- G: Group handle
        -- widget: Widget handle
        -- gx, gy: Parent coordinates
        -- cx, cy: Cursor coordinates
        -- state: Execution state
        -- Returns: Candidate
        local function Test (G, widget, gx, gy, cx, cy, state)
            local x, y, w, h = widget:GetRect()
			local candidate

            x, y = x + gx, y + gy

            if widget:GetAttachListHead() and widget:IsAllowed("attach_list_test") then
                widget:Signal("enter_attach_list_test")

                local vx, vy = widget:GetViewOrigin()

                x, y = x - vx, y - vy

                for aw in widget:AttachListIter() do
                    candidate = Test(G, aw, x, y, cx, cy, state)

                    if candidate ~= nil then
                        break
                    end
                end

                widget:Signal("leave_attach_list_test")
            end

            -- Perform the test.
            if candidate == nil and widget:IsAllowed("test") then
               candidate = widget:Signal("test", cx, cy, x, y, w, h, state)
            end

            -- Supply any candidate or the abort flag.
            return candidate
        end

        -- Execute body for resource usage
        local function ExecuteBody (G, cx, cy, state, resolve)
            SetLocalRect(G[_root], 0, 0)

            resolve(G, Test(G, G[_root], 0, 0, cx, cy, state), state)
        end

		-- Execution state --
		local States = Weak("k")

        --- Executes the group and resolves events generated during execution.<br><br>
		-- Up to this point, the group will be in <b>"testing"</b> mode.<br><br>
		-- Starting from the root, the execution proceeds through each widget's attach
		-- list, recursively testing each widget along the way.<br><br>
        -- If a widget has a non-empty attach list and the <b>"attach_list_test"</b>
        -- permission, as set by <b>Widget:Allow</b>, the attach list is tested. The
        -- widget is first sent a signal as<br><br>
        -- &nbsp&nbsp&nbsp<i><b>enter_attach_list_test(W)</b></i>,<br><br>
        -- where <i>W</i> is the widget. Each item in the attach list, in order (i.e.
		-- items at the front of the attach list are tested before items at the back),
		-- is then recursively tested. The widget is then sent a signal as<br><br>
		-- &nbsp&nbsp&nbsp<i><b>leave_attach_list_test(W)</b></i>,<br><br>
		-- where <i>W</i> is the widget.<br><br>
        -- If a widget has <b>"test"</b>permission, as set by <b>Widget:Allow</b>, then
        -- it is sent a signal as<br><br>
        -- &nbsp&nbsp&nbsp<i><b>test(W, cx, cy, x, y, w, h, state)</b></i>,<br><br>
        -- where <i>W</i> is the tested widget, <i>cx</i> and <i>cy</i> are the cursor
		-- coordinates, <i>x</i>, <i>y</i>, <i>w</i>, <i>h</i> are the test rect, and
		-- <i>state</i> is the "execution state". The <i>x</i> and <i>y</i> values will
		-- be relative to the position of the parent (for the root, this is always (0, 0))
		-- and also take its view origin into account.<br><br>
		-- A widget indicates success by returning a reference to a widget. Note that
		-- this may be another widget than itself, e.g. for sub-widgets. Once a widget
		-- has passed the test, testing stops, and this "candidate" widget is kept around
		-- for event resolution.<br><br>
		-- If a custom resolve is used, it is called and the group stays in testing
		-- mode.<br><br>
		-- Otherwise, the group switches to <b>"issuing_events"</b> mode.<br><br>
		-- Event issuing follows one of two paths:<br><br>
		-- <b>GROUP HAS A CHOSEN WIDGET</b><br><br>
		-- The chosen widget is first sent an <b>"enter_upkeep"</b> signal.<br><br>
		-- If the group has an entered widget and the cursor has left it, it is sent a
		-- <b>"leave"</b> signal.<br><br>
		-- If the group did not have an entered widget, on the other hand, and the chosen
		-- widget has been entered, it is sent an <b>"enter"</b> signal and the widget
		-- becomes the entered widget.<br><br>
		-- If the group did not have a grabbed widget, and the cursor has been pressed over
		-- the chosen widget, it is sent a <b>"grab"</b> signal and the widget becomes the
		-- grabbed widget.<br><br>
		-- If the group did have a grabbed widget, on the other hand, and the cursor state
		-- is now released, it is sent a <b>"drop"</b> signal.<br><br>
		-- If the group does not have a grabbed widget and the candidate is not the chosen
		-- widget, the chosen widget is sent an <b>"abandon"</b> signal. Otherwise it is
		-- sent a <b>"leave_upkeep"</b> signal.<br><br>
		-- <b>GROUP DOES NOT HAVE A CHOSEN WIDGET</b><br><br>
		-- The candidate becomes the chosen widget.<br><br>
		-- The candidate is sent an <b>"enter_choose"</b> signal.<br><br>
		-- The entered / grabbed widget decisions (and attendant <b>"enter"</b> and <b>
		-- "grab"</b> signals from the "has a chosen widget" logic is repeated here.<br><br>
		-- The candidate is sent a <b>"leave_choose"</b> signal.<br><br>
		-- All signals sent during event issuing have signature<br><br>
		-- &nbsp&nbsp&nbsp<i><b>signal(W, state)</b></i>,<br><br>
		-- where <i>signal</i> is the signal name, <i>W</i> is the relevant widget, and <i>
		-- state</i> is the execution state. Any listeners to these signals are alerted.<br><br>
        -- @param cx Cursor x-coordinate. This can be retrieved by widgets from the
		-- execution state as <b>state("cx")</b>.
		-- @param cy Cursor y-coordinate. This can be retrieved by widgets from the
		-- execution state as <b>state("cy")</b>.
        -- @param is_pressed If true, a press occurred at the cursor position. This
        -- can be retrieved from the execution state as <b>state("is_pressed")</b>.
        -- @param enter Clip region enter logic.<br><br>
        -- This can be retrieved by widgets from the execution state as <b>state("enter")
		-- </b> and called as <b>enter(x, y, w, h)</b>. If this returns a true result,
		-- the enter is successful.<br><br>
		-- By default, this is a no-op that always succeeds.
        -- @param leave Clip region leave logic.<br><br>
        -- This can be retrieved by widgets from the execution state as <b>state("leave")
		-- </b> and called as <b>leave()</b>. In general, it will undo state set by the
		-- <i>enter</i> logic and should only be called if that was successful.<br><br>
        -- @param resolve Event resolution logic.<br><br>
		-- If absent, the built-in logic is used. Otherwise, this should be a function
		-- with signature<br><br>
		-- &nbsp&nbsp&nbsp<i><b>resolve(G, candidate, state)</b></i>,<br><br>
		-- where <i>G</i> is this group, <i>candidate</i> is the widget that passed a
		-- test during execution, or <b>nil</b> if none passed, and <i>state</i> is the
		-- execution state.
        function UIGroup:Execute (cx, cy, is_pressed, enter, leave, resolve)
        	assert(type(cx) == "number", "Invalid cursor x")
        	assert(type(cy) == "number", "Invalid cursor y")
        	assert(enter == nil or IsCallable(enter), "Uncallable enter")
        	assert(leave == nil or IsCallable(leave), "Uncallable leave")
        	assert(resolve == nil or IsCallable(resolve), "Uncallable resolve")

			-- Bind the execution state, creating it if necessary.
			local state = States[self]

			if not state then
				local vars = {}

				function state (what, ...)
					if what == States then
						vars.cx, vars.cy, vars.is_pressed, vars.enter, vars.leave = ...
					elseif what == "cursor" then
						return vars.cx, vars.cy
					else
						return vars[what or 0]
					end
				end

				States[self] = state
			end

			state(States, cx, cy, not not is_pressed, enter or Identity, leave or NoOp) 

			-- Execute the group.
            Action(self, ExecuteBody, "testing", cx, cy, state, resolve or IssueEvents)
        end
    end

    -- Render --
    do
        -- Performs a render on the widget and through its attach list
        -- G: Group handle
        -- widget: Widget handle
        -- gx, gy: Parent coordinates
        -- state: Render state
        local function Render (G, widget, gx, gy, state)
            local x, y, w, h = widget:GetRect()

            x, y = x + gx, y + gy

            if widget:IsAllowed("render") then
                widget:Signal("render", x, y, w, h, state)
            end

            if widget:GetAttachListHead() and widget:IsAllowed("attach_list_render") then
                widget:Signal("enter_attach_list_render")

                local vx, vy = widget:GetViewOrigin()

                x, y = x - vx, y - vy

                for aw in widget:AttachListIter(true) do
                    Render(G, aw, x, y, state)
                end

                widget:Signal("leave_attach_list_render")
            end
        end

		-- Render state --
		local States = Weak("k")

        --- Renders the group.<br><br>
        -- Starting from the root, the render proceeds through each widget's attach list,
        -- recursively rendering each widget along the way.<br><br>
        -- If a widget has <b>"render"</b>permission, as set by <b>Widget:Allow</b>, then
        -- it is sent a signal as<br><br>
        -- &nbsp&nbsp&nbsp<i><b>render(W, x, y, w, h, state)</b></i>,<br><br>
        -- where <i>W</i> is the rendered widget, <i>x</i>, <i>y</i>, <i>w</i>, <i>h</i>
		-- are the render rect, and <i>state</i> is the "render state". The <i>x</i> and
		-- <i>y</i> values will be relative to the position of the parent (for the root,
		-- this is always (0, 0)) and also take its view origin into account.<br><br>
        -- If a widget has a non-empty attach list and the <b>"attach_list_render"</b>
        -- permission, as set by <b>Widget:Allow</b>, the attach list is rendered. The
        -- widget is first sent a signal as<br><br>
        -- &nbsp&nbsp&nbsp<i><b>enter_attach_list_render(W)</b></i>,<br><br>
        -- where <i>W</i> is the widget. Each item in the attach list, in reverse order
		-- (i.e. items at the front of the attach list are in front of items at the back),
		-- is then recursively rendered. The widget is then sent a signal as<br><br>
		-- &nbsp&nbsp&nbsp<i><b>leave_attach_list_render(W)</b></i>,<br><br>
		-- where <i>W</i> is the widget.<br><br>
		-- During this call, the group will be in <b>"rendering"</b> mode.
        -- @param enter Clip region enter logic.<br><br>
        -- This can be retrieved by widgets from the render state as <b>state("enter")</b>
		-- and called as <b>enter(x, y, w, h)</b>. If this returns a true result, the enter
		-- is successful.<br><br>
		-- By default, this is a no-op that always succeeds.
        -- @param leave Clip region leave logic.<br><br>
        -- This can be retrieved by widgets from the render state as <b>state("leave")</b>
        -- and called as <b>leave()</b>. In general, it will undo state set by the <i>enter
		-- </i> logic and should only be called if that was successful.<br><br>
		-- By default, this is a no-op.
        -- @see UIGroup:GetMode
        function UIGroup:Render (enter, leave)
        	assert(enter == nil or IsCallable(enter), "Uncallable enter")
        	assert(leave == nil or IsCallable(leave), "Uncallable leave")

			-- Bind the render state, creating it if necessary.
			local state = States[self]

			if not state then
				local vars = {}

				function state (what, ...)
					if what == States then
						vars.enter, vars.leave = ...
					else
						return vars[what or 0]
					end
				end

				States[self] = state
			end

			state(States, enter or Identity, leave or NoOp)

			-- Render the group.
            SetLocalRect(self[_root], 0, 0)

            Action(self, Render, "rendering", self[_root], 0, 0, state)
        end
    end

    -- Update --
    do
        -- Performs an update on the widget and through its attach list
        -- G: Group handle
        -- widget: Widget handle
        -- dt: Time lapse
        local function Update (G, widget, dt)
            if widget:IsAllowed("update") then
                widget:Signal("update", dt)
            end

            if widget:GetAttachListHead() and widget:IsAllowed("attach_list_update") then
                widget:Signal("enter_attach_list_update")

                for aw in widget:AttachListIter(true) do
                    Update(G, aw, dt)
                end

                widget:Signal("leave_attach_list_update")
            end
        end

        --- Updates the group.<br><br>
        -- Starting from the root, the update proceeds through each widget's attach list,
        -- recursively updating each widget along the way.<br><br>
        -- If a widget has <b>"update"</b>permission, as set by <b>Widget:Allow</b>, then
        -- it is sent a signal as<br><br>
        -- &nbsp&nbsp&nbsp<i><b>update(W, dt)</b></i>,<br><br>
        -- where <i>W</i> is the updated widget and <i>dt</i> is the time lapse during this
        -- update.<br><br>
        -- If a widget has a non-empty attach list and the <b>"attach_list_update"</b>
        -- permission, as set by <b>Widget:Allow</b>, the attach list is updated. The
        -- widget is first sent a signal as<br><br>
        -- &nbsp&nbsp&nbsp<i><b>enter_attach_list_update(W)</b></i>,<br><br>
        -- where <i>W</i> is the widget. Each item in the attach list, in reverse order (to
		-- correspond to <b>UIGroup:Render</b>), is then recursively updated. The widget is
		-- then sent a signal as<br><br>
		-- &nbsp&nbsp&nbsp<i><b>leave_attach_list_update(W)</b></i>,<br><br>
		-- where <i>W</i> is the widget.<br><br>
		-- During this call, the group will be in <b>"updating"</b> mode.
        -- @param dt Time lapse.
        -- @see UIGroup:GetMode
        -- @see UIGroup:Render
        function UIGroup:Update (dt)
			assert(type(dt) == "number" and dt >= 0, "Invalid time lapse")

            Action(self, Update, "updating", self[_root], dt)
        end
    end
end,

--- Class constructor.
-- @class function
-- @name Constructor
function(G)
	-- Message stream triggered on various events --
	G[_alert_streams] = {}

	-- Deferred events --
	G[_deferred] = {}

	-- Root widget --
	G[_root] = New("Widget", G)

	-- Signals --
	G[_root]:SetSignal("test", Identity)
end)