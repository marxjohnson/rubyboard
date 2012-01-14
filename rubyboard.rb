
# Define event constants
EVENT_LOCK = 32
EVENT_ERASE = 4
EVENT_WAKE = 2
EVENT_DETECT = 32
EVENT_CONTACT = 1

begin
	lsusb = `lsusb`
	if lsusb.split("\n").select{|l| l.include? "2047:ffe7"}.count == 0
		raise "Boogie Board Rip not currently connected"
	end

	begin
		dmesg = `dmesg`
		bbdev = dmesg.split("\n").select{|l| l.match "2047:FFE7.*hidraw[0-9]"}.pop.match("(hidraw[0-9]+)").to_s
		raise RuntimeError if bbdev.empty? 
	rescue NoMethodError, RuntimeError
		raise "Boogie Board Rip detected, but device's path could not be determined"
	end

	events = []
	threads = []

	thread = Thread.new do
		board = File.new("/dev/"+bbdev, 'r')
		while true do
			data = board.sysread(32)
			event = Array.new()
			data.bytes { |b| event << b }
			events << event
		end
	end
	threads << thread

	thread = Thread.new do
		previous = Array.new(32, 0)
		current = []
		while true do
			current = events.shift
			next if current.nil?

			if current[10] != previous[10]
				state = current[10]
				pstate = previous[10]
				if (pstate == pstate | EVENT_LOCK) && (state != state | EVENT_LOCK)
					puts "Board unlocked"
				elsif (pstate != pstate | EVENT_LOCK) && (state == state | EVENT_LOCK)
					puts "Board locked"
				end
				if (pstate == pstate | EVENT_ERASE) && (state != state | EVENT_ERASE)
					puts "Erase released"
				elsif (pstate != pstate | EVENT_ERASE) && (state == state | EVENT_ERASE)
					puts "Erase Pressed"
				end
				if (pstate == pstate | EVENT_WAKE) && (state != state | EVENT_WAKE)
					puts "Wake released"
				elsif (pstate != pstate | EVENT_WAKE) && (state == state | EVENT_WAKE)
					puts "Wake Pressed"
				end
			end
			if current[3] != previous[3]
				state = current[3]
				pstate = previous[3]
				if (pstate == pstate | EVENT_DETECT) && (state != state | EVENT_DETECT)
					puts "Pen Lost"
				elsif (pstate != pstate | EVENT_DETECT) && (state == state | EVENT_DETECT)
					puts "Pen Detected"
				end
				if (pstate == pstate | EVENT_CONTACT) && (state != state | EVENT_CONTACT)
					puts "Pen contact lost"
				elsif (pstate != pstate | EVENT_CONTACT) && (state == state | EVENT_CONTACT)
					puts "Pen contact detected"
				end
			end
			cury = current[4]+(current[5]*256)
			curx = current[6]+(current[7]*256)
			prey = previous[4]+(previous[5]*256)
			prex = previous[6]+(previous[7]*256)
			if cury != prey || curx != prex
				puts "Pen moved from ("+prex.to_s+","+prey.to_s+") to ("+curx.to_s+","+cury.to_s+")"
			end	
			previous = current
		end
	end
	threads << thread

	threads.each{ |thread| thread.join}
	
rescue RuntimeError => error
	puts error
end
	
