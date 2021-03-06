/obj/item/device/assembly/signaler
	name = "remote signaling device"
	desc = "Used to remotely activate devices.  Tap against another secured signaler to transfer configuration."
	icon_state = "signaller"
	item_state = "signaler"
	origin_tech = list(TECH_MAGNET = 1)
	matter = list(DEFAULT_WALL_MATERIAL = 1000, "glass" = 200, "waste" = 100)
	wires = WIRE_RECEIVE | WIRE_PULSE | WIRE_RADIO_PULSE | WIRE_RADIO_RECEIVE

	secured = TRUE

	var/code = 30
	var/frequency = 1457
	var/delay = 0
	var/airlock_wire = null
	var/datum/wires/connected = null
	var/datum/radio_frequency/radio_connection
	var/deadman = FALSE

/obj/item/device/assembly/signaler/Initialize()
	. = ..()
	set_frequency(frequency)

/obj/item/device/assembly/signaler/activate()
	if(!process_cooldown())
		return FALSE
	signal()
	return TRUE

/obj/item/device/assembly/signaler/update_icon()
	if(holder)
		holder.update_icon()

/obj/item/device/assembly/signaler/interact(var/mob/user)
	var/t1 = "-------"
	var/dat = {"
<TT>

<A href='byond://?src=\ref[src];send=1'>Send Signal</A><BR>
<B>Frequency/Code</B> for signaler:<BR>
Frequency:
<A href='byond://?src=\ref[src];freq=-10'>-</A>
<A href='byond://?src=\ref[src];freq=-2'>-</A>
[format_frequency(src.frequency)]
<A href='byond://?src=\ref[src];freq=2'>+</A>
<A href='byond://?src=\ref[src];freq=10'>+</A><BR>

Code:
<A href='byond://?src=\ref[src];code=-5'>-</A>
<A href='byond://?src=\ref[src];code=-1'>-</A>
[src.code]
<A href='byond://?src=\ref[src];code=1'>+</A>
<A href='byond://?src=\ref[src];code=5'>+</A><BR>
[t1]
</TT>"}
	user << browse(dat, "window=radio")
	onclose(user, "radio")

/obj/item/device/assembly/signaler/Topic(href, href_list, state = deep_inventory_state)
	if(..())
		return TRUE

	if(!usr.canmove || usr.stat || usr.restrained() || !in_range(loc, usr))
		usr << browse(null, "window=radio")
		onclose(usr, "radio")
		return

	if (href_list["freq"])
		var/new_frequency = (frequency + text2num(href_list["freq"]))
		if(new_frequency < RADIO_LOW_FREQ || new_frequency > RADIO_HIGH_FREQ)
			new_frequency = sanitize_frequency(new_frequency, RADIO_LOW_FREQ, RADIO_HIGH_FREQ)
		set_frequency(new_frequency)

	if(href_list["code"])
		src.code += text2num(href_list["code"])
		src.code = round(src.code)
		src.code = min(100, src.code)
		src.code = max(1, src.code)

	if(href_list["send"])
		spawn( 0 )
			signal()

	if(usr)
		attack_self(usr)

/obj/item/device/assembly/signaler/attackby(var/obj/item/weapon/W, mob/user, params)
	if(issignaler(W))
		var/obj/item/device/assembly/signaler/signaler2 = W
		if(secured && signaler2.secured)
			code = signaler2.code
			set_frequency(signaler2.frequency)
			to_chat(user, "You transfer the frequency and code of [signaler2] to [src].")
	else
		..()

/obj/item/device/assembly/signaler/proc/signal()
	if(!radio_connection)
		return
	if(is_jammed(src))
		return

	var/datum/signal/signal = new
	signal.source = src
	signal.encryption = code
	signal.data["message"] = "ACTIVATE"
	radio_connection.post_signal(src, signal)

/obj/item/device/assembly/signaler/pulse(var/radio = 0)
	if(is_jammed(src))
		return FALSE
	if(src.connected && src.wires)
		connected.Pulse(src)
	else if(holder)
		holder.process_activation(src, 1, 0)
	else
		..(radio)
	return TRUE

/obj/item/device/assembly/signaler/receive_signal(datum/signal/signal)
	if(!signal)
		return FALSE
	if(signal.encryption != code)
		return FALSE
	if(!(src.wires & WIRE_RADIO_RECEIVE))
		return FALSE
	if(is_jammed(src))
		return FALSE
	pulse(1)

	if(!holder)
		for(var/mob/O in hearers(1, src.loc))
			O.show_message("[bicon(src)] *beep* *beep*", 3, "*beep* *beep*", 2)

/obj/item/device/assembly/signaler/proc/set_frequency(new_frequency)
	if(!frequency)
		return
	if(!radio_controller)
		sleep(20)
	if(!radio_controller)
		return

	radio_controller.remove_object(src, frequency)
	frequency = new_frequency
	radio_connection = radio_controller.add_object(src, frequency, RADIO_CHAT)

/obj/item/device/assembly/signaler/process()
	if(!deadman)
		STOP_PROCESSING(SSobj, src)
	var/mob/M = src.loc
	if(!M || !ismob(M))
		if(prob(5))
			signal()
		deadman = FALSE
		STOP_PROCESSING(SSobj, src)
	else if(prob(5))
		M.visible_message("[M]'s finger twitches a bit over [src]'s signal button!")

/obj/item/device/assembly/signaler/verb/deadman_it()
	set src in usr
	set name = "Threaten to push the button!"
	set desc = "BOOOOM!"
	deadman = TRUE
	START_PROCESSING(SSobj, src)
	log_and_message_admins("is threatening to trigger a signaler deadman's switch")
	usr.visible_message("<font color='red'>[usr] moves their finger over [src]'s signal button...</font>")

/obj/item/device/assembly/signaler/Destroy()
	if(radio_controller)
		radio_controller.remove_object(src,frequency)
	frequency = 0
	. = ..()
