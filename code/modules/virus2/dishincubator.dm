#define FED_PING_DELAY 40

/obj/machinery/disease2/incubator
	name = "Pathogenic incubator"
	density = 1
	anchored = 1
	icon = 'icons/obj/virology.dmi'
	icon_state = "incubator"

	machine_flags = SCREWTOGGLE | CROWDESTROY

	var/obj/item/weapon/virusdish/dish
	var/obj/item/weapon/reagent_containers/glass/beaker = null
	var/radiation = 0

	var/on = 0
	var/power = 0

	var/foodsupply = 0
	var/toxins = 0
	var/mutatechance = 5
	var/growthrate = 3

	var/virusing

	var/last_notice
/obj/machinery/disease2/incubator/New()
	. = ..()

	component_parts = newlist(
		/obj/item/weapon/circuitboard/incubator,
		/obj/item/weapon/stock_parts/matter_bin,
		/obj/item/weapon/stock_parts/micro_laser,
		/obj/item/weapon/stock_parts/micro_laser,
		/obj/item/weapon/stock_parts/scanning_module,
		/obj/item/weapon/stock_parts/scanning_module,
		/obj/item/weapon/reagent_containers/glass/beaker,
	)

	RefreshParts()

/obj/machinery/disease2/incubator/RefreshParts()
	var/scancount = 0
	var/lasercount = 0
	for(var/obj/item/weapon/stock_parts/SP in component_parts)
		if(istype(SP, /obj/item/weapon/stock_parts/scanning_module)) scancount += SP.rating-1
		if(istype(SP, /obj/item/weapon/stock_parts/micro_laser)) lasercount += SP.rating-1
	mutatechance = initial(mutatechance) + scancount
	growthrate = initial(growthrate) + lasercount

/obj/machinery/disease2/incubator/attackby(var/obj/B as obj, var/mob/user as mob)
	..()
	if(istype(B, /obj/item/weapon/reagent_containers/glass) || istype(B,/obj/item/weapon/reagent_containers/syringe))

		if(src.beaker)
			if(istype(beaker,/obj/item/weapon/reagent_containers/syringe))
				to_chat(user, "A syringe is already loaded into the machine.")
			else
				to_chat(user, "A beaker is already loaded into the machine.")
			return

		if(user.drop_item(B, src))
			src.beaker =  B

			if(istype(B,/obj/item/weapon/reagent_containers/syringe))
				to_chat(user, "You add the syringe to the machine!")
				src.updateUsrDialog()
			else
				to_chat(user, "You add the beaker to the machine!")
				src.updateUsrDialog()
	else
		if(istype(B,/obj/item/weapon/virusdish))
			if(src.dish)
				to_chat(user, "A dish is already loaded into the machine.")
				return

			if(user.drop_item(B, src))
				src.dish =  B

				if(istype(B,/obj/item/weapon/virusdish))
					to_chat(user, "You add the dish to the machine!")
					src.updateUsrDialog()

/obj/machinery/disease2/incubator/Topic(href, href_list)
	if(..()) return 1

	if(usr) usr.set_machine(src)

	if (href_list["ejectchem"])
		if(beaker)
			beaker.forceMove(src.loc)
			beaker = null
	if(!dish)
		return
	if (href_list["power"])
		on = !on
		if(on)
			icon_state = "incubator_on"
			if(dish && dish.virus2)
				dish.virus2.log += "<br />[timestamp()] Incubation starting by [key_name(usr)] {food=[foodsupply],rads=[radiation]}"
		else
			icon_state = "incubator"
	if (href_list["ejectdish"])
		if(dish)
			dish.loc = src.loc
			dish = null
	if (href_list["rad"])
		radiation += 10
	if (href_list["flush"])
		radiation = 0
		toxins = 0
		foodsupply = 0

	if(href_list["virus"])
		if (!dish)
			say("No viral culture sample detected.")
		else
			var/datum/reagent/blood/B = locate(/datum/reagent/blood) in beaker.reagents.reagent_list
			if (!B)
				say("No suitable breeding environment detected.")
			else
				if (!B.data["virus2"])
					B.data["virus2"] = list()
				var/datum/disease2/disease/D = dish.virus2.getcopy()
				D.log += "<br />[timestamp()] Injected into blood via [src] by [key_name(usr)]"
				var/list/virus = list("[dish.virus2.uniqueID]" = D)
				B.data["virus2"] = virus

				say("Injection complete.")
	src.add_fingerprint(usr)
	src.updateUsrDialog()

/obj/machinery/disease2/incubator/attack_hand(mob/user as mob)
	if(stat & BROKEN)
		return
	user.set_machine(src)
	var/dat = list()
	if(!dish)
		dat += "Please insert dish into the incubator.<BR>"
	var/string = "Off"
	if(on)
		string = "On"
	dat += "Power status: <A href='?src=\ref[src];power=1'>[string]</a>"
	dat += "<BR>"
	dat += "Food supply: [foodsupply]"
	dat += "<BR>"
	dat += "Radiation levels: [radiation] RADS (<A href='?src=\ref[src];rad=1'>Radiate</a>)"
	dat += "<BR>"
	dat += "Toxins: [toxins]"
	if(dish)
		dat += "<BR>"
		dat += "Growth level: [dish.growth]"
	dat += "<BR><BR>"
	if(beaker)
		dat += "Eject chemicals: <A href='?src=\ref[src];ejectchem=1'> Eject</a>"
		dat += "<BR>"
	if(dish)
		dat += "Eject Virus dish: <A href='?src=\ref[src];ejectdish=1'> Eject</a>"
		dat += "<BR>"
		if(beaker)
			dat += "Breed viral culture in beaker: <A href='?src=\ref[src];virus=1'> Start</a>"
			dat += "<BR>"
	dat += "<br><hr><A href='?src=\ref[src];flush=1'>Flush system</a><BR>"
	dat = list2text(dat)
	var/datum/browser/popup = new(user, "dish_incubator", "Pathogenic Incubator", 575, 400, src)
	popup.set_content(dat)
	popup.open()
	onclose(user, "dish_incubator")

/obj/machinery/disease2/incubator/process()
	if(dish && on && dish.virus2)
		use_power(50,EQUIP)
		if(!powered(EQUIP))
			on = 0
			icon_state = "incubator"
		if(foodsupply)
			foodsupply -= 1
			dish.growth += growthrate
			if(dish.growth >= 100)
				if(icon_state != "incubator_fed")
					icon_state = "incubator_fed"
				if(last_notice + FED_PING_DELAY < world.time)
					last_notice = world.time
					alert_noise("ping")
		if(radiation)
			if(radiation > 50 & prob(mutatechance))
				dish.virus2.log += "<br />[timestamp()] MAJORMUTATE (incubator rads)"
				dish.virus2.majormutate()
				if(dish.info)
					dish.info = "OUTDATED : [dish.info]"
					dish.analysed = 0
				alert_noise("beep")
				flick("incubator_mut", src)

			else if(prob(mutatechance))
				dish.virus2.minormutate()
			radiation -= 1
		if(toxins && prob(5))
			dish.virus2.infectionchance -= 1
		if(toxins > 50)
			dish.virus2 = null
	else if(!dish)
		on = 0
		icon_state = "incubator"

	if(beaker)
		if(!beaker.reagents.remove_reagent("virusfood",5))
			foodsupply += 10
		if(!beaker.reagents.remove_reagent("toxin",1))
			toxins += 1

	src.updateUsrDialog()