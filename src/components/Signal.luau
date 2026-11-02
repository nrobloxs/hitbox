--!strict

export type Connection = {
	Connected: boolean,
	Disconnect: (self: Connection) -> (),
}

type Listener = {
	Connected: boolean,
	Disconnect: (self: Connection) -> (),
	_callback: (...any) -> (),
	_once: boolean,
	_next: Listener?,
	_signal: SignalState?,
}

type SignalState = {
	_head: Listener?,
	_tail: Listener?,
	_firing: number,
	_destroyed: boolean,
}

export type Signal<Arguments...> = {
	Connect: (self: Signal<Arguments...>, callback: (Arguments...) -> ()) -> Connection,
	Once: (self: Signal<Arguments...>, callback: (Arguments...) -> ()) -> Connection,
	Fire: (self: Signal<Arguments...>, Arguments...) -> (),
	Wait: (self: Signal<Arguments...>) -> Arguments...,
	DisconnectAll: (self: Signal<Arguments...>) -> (),
	Destroy: (self: Signal<Arguments...>) -> (),
} & SignalState

local Signal = {}
Signal.__index = Signal

local function compact(signal: SignalState)
	if signal._firing > 0 then
		return
	end

	local first: Listener? = nil
	local last: Listener? = nil
	local current = signal._head
	while current do
		local nextListener = current._next
		if current.Connected then
			if last then
				last._next = current
			else
				first = current
			end
			last = current
		else
			current._next = nil
		end
		current = nextListener
	end

	if last then
		last._next = nil
	end
	signal._head = first
	signal._tail = last
end

local function disconnect(connection: Connection)
	if not connection.Connected then
		return
	end
	connection.Connected = false

	local listener = connection :: Listener
	local signal = listener._signal
	listener._signal = nil
	if signal then
		compact(signal)
	end
end

function Signal.new<Arguments...>(): Signal<Arguments...>
	local state: SignalState = {
		_head = nil,
		_tail = nil,
		_firing = 0,
		_destroyed = false,
	}
	return (setmetatable(state, Signal) :: any) :: Signal<Arguments...>
end

function Signal.Connect<Arguments...>(self: Signal<Arguments...>, callback: (Arguments...) -> ()): Connection
	assert(not self._destroyed, "Cannot connect to a destroyed Signal")
	local listener: Listener = {
		Connected = true,
		Disconnect = disconnect,
		_callback = callback,
		_once = false,
		_next = nil,
		_signal = self,
	}

	if self._tail then
		self._tail._next = listener
	else
		self._head = listener
	end
	self._tail = listener
	return listener
end

function Signal.Once<Arguments...>(self: Signal<Arguments...>, callback: (Arguments...) -> ()): Connection
	local connection = self:Connect(callback)
	local listener = connection :: Listener
	listener._once = true
	return connection
end

function Signal.Fire<Arguments...>(self: Signal<Arguments...>, ...: Arguments...)
	if self._destroyed then
		return
	end

	self._firing += 1
	local current = self._head
	while current do
		local nextListener = current._next
		if current.Connected then
			if current._once then
				disconnect(current)
			end
			current._callback(...)
		end
		current = nextListener
	end
	self._firing -= 1
	compact(self)
end

function Signal.Wait<Arguments...>(self: Signal<Arguments...>): Arguments...
	local thread = coroutine.running()
	assert(thread, "Signal:Wait must run in a coroutine")
	self:Once(function(...: Arguments...)
		task.spawn(thread, ...)
	end)
	return coroutine.yield()
end

function Signal.DisconnectAll(self: SignalState)
	local current = self._head
	while current do
		local nextListener = current._next
		current.Connected = false
		current._signal = nil
		if self._firing == 0 then
			current._next = nil
		end
		current = nextListener
	end
	if self._firing == 0 then
		self._head = nil
		self._tail = nil
	end
end

function Signal.Destroy(self: SignalState)
	if self._destroyed then
		return
	end
	Signal.DisconnectAll(self)
	self._destroyed = true
end

return Signal
