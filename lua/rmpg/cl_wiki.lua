-- Client: the mod's wiki, the first tab of the C menu window (cl_desktop.lua). Topics on the left, the text on the
-- right, in the player's language.
RMPG = RMPG or {}

local TOPICS = {
	ru = {
		{ "icon16/information.png", "С чего начать", "Всё из мода лежит в меню спавна (Q): Оружие → Rick and Morty и Сущности → Rick and Morty.\n\nЭто окно (зажмите C, значок Rick and Morty слева сверху) — вики, ваши настройки, друзья, импланты и настройки сервера по разделам. Настройки сервера меняет суперадмин, остальные их только видят.\n\nВещи с пометкой W.I.P ещё в разработке и могут работать с ошибками — при их спавне об этом напомнит сообщение." },
		{ "icon16/wand.png", "Портальная пушка", "ЛКМ — открыть портал. ПКМ — голографическое меню. R — сменить колбу. E + ПКМ — закрыть свои порталы. Зажать колёсико — круговое меню быстрых действий (его можно настроить).\n\nПорталы сохраняют скорость и спасают от падения. Через них проходят игроки, NPC, пропы и машины, а NPC, которые за вами гонятся, идут следом.\n\nЖидкость в колбе тратится на выстрелы, запасные колбы меняются на R. Энергоядро в куполе даёт бесконечный заряд.\n\nВ меню «Пушка» — модель (обычная, Прайм, Злого Морти, прототип, детская и две другого типа), цвет жидкости, свой цвет корпуса и самоуничтожение (зажать кнопку).\n\nVRMod: порталы открываются туда, куда смотрит ствол в правой руке, а не взгляд; пушка и лазер держатся в руке." },
		{ "icon16/world.png", "Режимы порталов", "Режим выбирается в меню «Назначение» или на круговом меню.\n\n• Случайное место — выход в случайной свободной точке карты.\n• Сохранённая локация — точка из вкладки «Локации»; локациями можно делиться с друзьями или со всеми.\n• Найти игрока — выход шагах в десяти от выбранного игрока.\n• Связанные порталы — первый выстрел вход, второй выход.\n• Быстрый портал — выход там, куда целитесь, вход рядом с вами (кнопка B работает в любом режиме).\n• Портал-ловушка — кто коснётся этого портала (даже вы), того затянет и разорвёт.\n• Цепочка порталов — каждый выстрел новый портал: первый ведёт во второй, второй в третий.\n• По координатам — выход в точке X, Y, Z с поворотом и наклоном, есть кнопки «Моя позиция» и «Точка прицела».\n• На другую карту — смотрите отдельную статью." },
		{ "icon16/world_go.png", "Переход на другую карту", "Режим «На другую карту»: выберите карту из списка сервера и выстрелите — откроется портал с названием карты над ним.\n\nКогда в портал войдёт тот, кто его открыл: если на сервере больше никого нет, карта меняется сразу; если есть другие игроки, начинается отсчёт (настройка сервера), и все, кто зайдёт в портал, ждут внутри. Выйти можно кнопкой «Выйти из портала», E или пробелом; если выйдет открывший, переход отменяется.\n\nНа новой карте все, кто был внутри, выходят из одного портала. Открывать такие порталы может только суперадмин или все — это настройка сервера." },
		{ "icon16/gun.png", "Лазерная пушка Рика", "ЛКМ — стрельба, пока зажата. Пушка греется и после серии выстрелов перегревается — придётся подождать.\n\nПКМ — зажать, чтобы накопить заряд, как у пушки Гаусса; отпустить — тяжёлый луч пробивает тела и тонкие стены, отскакивает от стен под острым углом и отбрасывает вас назад. Если держать полный заряд слишком долго, будет перегрузка." },
		{ "icon16/heart.png", "Импланты", "Чипы имплантов лежат в Сущностях: подойдите и нажмите E, чтобы вживить. Во вкладке «Импланты» этого окна — порядок, в котором щит и эвакуация принимают удар, кнопки и кнопка «Достать» (чип выпадет перед вами).\n\n• Энергощит поглощает урон и восстанавливается.\n• Эвакуация уводит вас от пули или взрыва на пару метров.\n• Лазер Акиры (W.I.P) — в боевом режиме (колёсико мыши): H — выстрел из руки, снимает около 40% здоровья цели; Y — усиленный залп, который сжигает всё на пути, потом долго перезаряжается.\n• Щупальце (W.I.P) — хватает и тащит, работает как крюк, ловит при падении.\n• Чип Рика Прайма (W.I.P) — раны заживают через 2–3 секунды после удара, кровь пропадает. Смертельный удар (и взрыв) — фальшивая смерть: вы падаете рагдоллом, встаёте со смехом с 250 здоровья и 50 брони, потом чип перезаряжается. K создаёт ваше тело, L переносит сознание в другое тело; пока чип перезаряжается, смерть переносит вас в ближайшее тело. Тела ходят за вами, достают пистолет и стреляют по NPC, которые вас ненавидят, и по тем, кто ранил вас или тело (настройка сервера «Тела защищают хозяина»)." },
		{ "icon16/arrow_rotate_clockwise.png", "Гравитационные ботинки (W.I.P)", "ПКМ — включить или выключить. Включённые работают с любым оружием в руках.\n\nИдите в стену — и вы стоите на ней, дойдите до края — и обойдёте его. Камера и модель игрока переворачиваются вместе с вами. Портал возвращает обычную гравитацию до следующей поверхности." },
		{ "icon16/eye.png", "Повязка Злого Морти", "ЛКМ — надеть. У повязки своё круговое меню на колёсике: куда ведут порталы, тепловизор (сквозь стены, паразит в голове светится ярче всего), скан X-RAY (сведения и последние убийства), камера, бинокль, самонаводка на выбранную часть тела и взлом механизмов — E на то, что в центре экрана (кнопки, двери, турели, динамит; бомбы можно разминировать и перехватить).\n\nПоложение повязки и верёвки настраивается в редакторе (Утилиты → Rick and Morty)." },
		{ "icon16/user.png", "Коробка Мисиксов", "Нажмите кнопку на коробке — появится Мистер Мисикс и выполнит задание: охранять, лечить, принести вещь, охотиться за кем-то или создать сущность / NPC. Выполнив задание, он исчезает, а если затянуть — начинает нервничать.\n\nМисиксы бегут за вами через порталы. Чёрный список того, что им нельзя создавать, — в настройках сервера." },
		{ "icon16/user_add.png", "Операция «Феникс»", "Шприц ДНК: ЛКМ по рагдоллу человека — взять его ДНК, ЛКМ по колбе «Феникса» — вколоть. ПКМ — ваша собственная ДНК.\n\nВ колбе растёт тело: сначала мясо, потом кожа. Окно колбы (E) показывает рост и даёт выбрать сознание и размер тела. Если вы умрёте, готовое тело примет ваше сознание. Стекло можно разбить — тело выпадет." },
		{ "icon16/emoticon_smile.png", "Превращение в овощ (W.I.P)", "Возьмите шприц ДНК и ткните им (ЛКМ) в картошку из Сущностей или в арбуз из пропов, затем ПКМ — вколоть себе.\n\nВы станете им, с вашей маленькой головой на боку. Это ещё в разработке и может работать с ошибками. Вид от третьего лица, вы перекатываетесь, когда вы двигаетесь, и умеет слегка подпрыгивать; оружием пользоваться нельзя, как в Prop Hunt.\n\nЗажмите E на секунду, чтобы стать собой. Если вас убьют, овощ останется лежать." },
		{ "icon16/bug.png", "Червь мозга", "Червь мозга (NPC) ищет добычу и трупы, растёт, ест пропы и людей, строит логова: матка откладывает яйца, рабочие тащат домой пропы и трупы, колония растёт и защищается.\n\nШприц симпатида: червь в голову — он растёт, вместо здоровья «??», а всё вокруг чудесно, потом червь вылезает. Пустым шприцем его можно вытащить. Плюмбус, отданный червю, приручает его." },
		{ "icon16/pill.png", "Драматичные пилюли", "Банка на 25 штук: вытряхните пилюлю и съешьте. Вы исчезнете, как в кино, и появитесь в другом месте — там, куда ведёт ваша портальная пушка, или в случайном (выбирается в банке)." },
		{ "icon16/bomb.png", "Бомбы и детонатор", "Бомба Рика Прайма: свяжите её с детонатором и подорвите — во время отсчёта она тянет всё к себе, потом распыляет всё рядом и бьёт волной дальше.\n\nНейтринная бомба: коды запуска и отключения приходят в чат создателю, время до взрыва задаётся на её клавиатуре. Взрыв на полкарты, чёрная дыра и горящие метеориты. Детонатор работает и с ней." },
		{ "icon16/star.png", "Плюмбус", "Плюмбус жмякается с приятным звуком, его можно перехватить за шею. Отдайте его червю мозга — червь станет ручным, будет ходить за вами и мяукать." },
		{ "icon16/drink.png", "Чаны с кислотой (W.I.P)", "Два шуточных чана в Сущностях. В них можно запрыгнуть (с приседанием) или бросить что-нибудь.\n\n• Настоящая кислота растворяет всё живое до скелета, который всплывает, а пропы съёживаются с шипением.\n• Фальшивая кислота только притворяется: вы «растворяетесь» на глазах у всех — крик, из люка BONES всплывает скелет, в чате сообщение, — а сами прячетесь на дне, невидимые, и NPC вас не трогают. Выпрыгните из чана, чтобы вернуться." },
		{ "icon16/group.png", "Гости из других реальностей", "Иногда из портала приходит ваша копия из другого измерения — настоящий бот с вашим именем и видом (или копия Lambda Player). Она может напасть или подарить подарок. Частота, сила и поведение гостей — в настройках сервера." },
		{ "icon16/cog.png", "Настройки и права", "Вкладка «Игрок» этого окна — ваши настройки: язык, интерфейс, звуки, положение пушки в руке. «Друзья» — кому доверяете (им видны ваши метки, Мисиксы их пропускают).\n\nОстальные вкладки — настройки сервера по разделам; менять их может только суперадмин. То же самое есть в меню спавна: Утилиты → Rick and Morty." },
	},
	en = {
		{ "icon16/information.png", "Getting started", "Everything of the mod is in the spawn menu (Q): Weapons → Rick and Morty and Entities → Rick and Morty.\n\nThis window (hold C, the Rick and Morty icon at the top left) has the wiki, your settings, friends, implants and the server settings by section. Server settings are changed by a superadmin; everyone else only sees them.\n\nThings marked W.I.P are still being made and may have bugs; a message says so when you spawn one." },
		{ "icon16/wand.png", "Portal gun", "LMB opens a portal. RMB opens the holographic menu. R swaps the flask. E + RMB closes your portals. Hold the mouse wheel for the radial menu of quick actions (you can set it up).\n\nPortals keep your speed and save you from falls. Players, NPCs, props and vehicles go through, and NPCs chasing you follow.\n\nThe fluid in the flask is spent on shots; spare flasks go in with R. An energy core in the dome gives infinite charges.\n\nThe Gun menu has the model (Classic, Prime, Evil Morty's, the prototype, the kids' and two of another type), the fluid colour, a body colour of your own and the self-destruct (hold the button).\n\nVRMod: portals open where the barrel in your right hand points, not where you look; the gun and the laser sit in the hand." },
		{ "icon16/world.png", "Portal modes", "Pick the mode in the Destination menu or on the radial menu.\n\n• Random place: the exit opens at a random free spot on the map.\n• Saved location: a spot from the Locations tab; locations can be shared with friends or everyone.\n• Find player: the exit opens about ten steps from the chosen player.\n• Linked portals: the first shot is the entrance, the second the exit.\n• Quick portal: the exit where you aim, the entrance next to you (the B key works in any mode).\n• Portal trap: whoever touches it, you too, is pulled in and torn apart.\n• Portal chain: every shot is a new portal, the first leads into the second, the second into the third.\n• By coordinates: the exit at X, Y, Z with a turn and tilt; My position and Where I aim fill them in.\n• To another map: see its own page." },
		{ "icon16/world_go.png", "Travel to another map", "The To another map mode: pick a map from the server's list and fire, and a portal opens with the map's name over it.\n\nWhen the one who opened it walks in: if nobody else is on the server, the map changes at once; otherwise a countdown starts (a server setting) and everyone who walks in waits inside. Step out with the Step out button, E or Space; if the opener steps out, the trip is off.\n\nOn the new map everyone who was inside comes out of one portal. Whether only superadmins or everyone may open these portals is a server setting." },
		{ "icon16/gun.png", "Rick's laser gun", "LMB fires while held. The gun heats up and overheats after a burst, then you have to wait.\n\nHold RMB to build up a charge like the Gauss gun; let go and a heavy beam goes through bodies and thin walls, bounces off walls at a glancing angle and throws you back. Hold a full charge too long and it overloads." },
		{ "icon16/heart.png", "Implants", "Implant chips are in Entities: walk up and press E to implant one. The Implants tab of this window has the order in which the shield and the evacuation take a hit, the buttons, and Take out (the chip falls in front of you).\n\n• Energy shield soaks up damage and recharges.\n• Evacuation takes you a couple of metres away from a bullet or a blast.\n• Akira Laser (W.I.P), in combat mode (mouse wheel): H fires a shot from the hand that takes about 40% of the target's health; Y is the power burst that burns everything in its way and then recharges for a long time.\n• Tentacle (W.I.P) grabs and drags, works as a hook and catches you when you fall.\n• Rick Prime chip (W.I.P): wounds close 2-3 seconds after a hit and the blood goes. A lethal hit (a blast too) is a fake death: you fall as a ragdoll and get up laughing with 250 health and 50 armour, then the chip recharges. K makes a body of yourself, L moves your mind into another body; while the chip recharges, dying moves you into the nearest body. Your bodies follow you, take out a pistol and shoot NPCs that hate you and whoever hurt you or a body (the server setting \"Bodies guard their owner\")." },
		{ "icon16/arrow_rotate_clockwise.png", "Gravity boots (W.I.P)", "RMB turns them on or off. On, they work whatever you hold.\n\nWalk into a wall and you stand on it, walk over an edge and you go round it. The camera and the player model turn over with you. A portal gives normal gravity back until the next surface." },
		{ "icon16/eye.png", "Evil Morty's eyepatch", "LMB puts it on. The patch has its own radial menu on the mouse wheel: where portals lead, the thermal view (through walls; a parasite in a head burns brightest), the X-ray scan (details and last kills), a camera, binoculars, aim help on a chosen body part and hacking mechanisms - E on whatever is in the middle of the screen (buttons, doors, turrets, dynamite; bombs can be defused and taken over).\n\nThe patch and strap are placed in the editor (Utilities → Rick and Morty)." },
		{ "icon16/user.png", "Meeseeks box", "Press the button on the box and Mr. Meeseeks appears to do a job: guard, heal, bring something, hunt someone, or make an entity / NPC. Once it is done he vanishes; drag it out and he gets nervous.\n\nMeeseeks follow you through portals. The list of what they must not make is in the server settings." },
		{ "icon16/user_add.png", "Operation Phoenix", "The DNA syringe: LMB on a human ragdoll takes its DNA, LMB on the Phoenix tank injects it. RMB is your own DNA.\n\nA body grows in the tank, meat first, then skin. The tank window (E) shows the growth and lets you pick the mind and the body size. If you die, a ready body takes your mind. The glass can be broken and the body falls out." },
		{ "icon16/emoticon_smile.png", "Turning into a vegetable (W.I.P)", "Take the DNA syringe, stab (LMB) a potato from Entities or a watermelon from the props, then RMB injects it into you.\n\nYou become it, with your own small head on its side. It is still being made and may have bugs. The view is third person, you roll as you move and can hop a little; you cannot use weapons, like in Prop Hunt.\n\nHold E for a second to be yourself again. If you are killed, the vegetable stays lying there." },
		{ "icon16/bug.png", "Brain worm", "The brain worm (NPC) looks for prey and corpses, grows, eats props and people and builds lairs: the queen lays eggs, workers haul props and corpses home, the colony grows and defends itself.\n\nThe Sympathid syringe puts a worm in a head: it grows, health shows as ??, everything around is wonderful, and then the worm comes out. An empty syringe can pull it back out. A plumbus given to a worm tames it." },
		{ "icon16/pill.png", "Dramatic pills", "A bottle of 25: shake out a pill and eat it. You vanish like in a film and appear somewhere else: where your portal gun leads, or at random (chosen on the bottle)." },
		{ "icon16/bomb.png", "Bombs and the detonator", "Rick Prime's bomb: link it to the detonator and set it off. During the countdown it pulls everything in, then disintegrates everything near and hits further out with a blast wave.\n\nThe neutrino bomb: the launch and disarm codes go to its creator in the chat, the timer is set on its keypad. A blast over half the map, a black hole and burning meteors. The detonator works with it too." },
		{ "icon16/star.png", "Plumbus", "The plumbus squeaks nicely and can be held by the neck. Give it to a brain worm and the worm becomes tame: it follows you around and meows." },
		{ "icon16/drink.png", "Acid vats (W.I.P)", "Two joke vats in Entities. Jump in (crouch-jump) or throw something in.\n\n• Real acid dissolves everything living down to a skeleton that floats up, and props shrink away in a hiss.\n• Fake acid only pretends: you dissolve in front of everyone - a scream, a skeleton floats up out of the BONES hatch, a line in the chat - while you hide at the bottom, unseen, and NPCs leave you alone. Jump out of the vat to come back." },
		{ "icon16/group.png", "Visitors from other realities", "Now and then your copy from another dimension comes out of a portal: a real bot with your name and look (or a copy of a Lambda Player). It may attack or bring a gift. How often, how hard and how they behave is in the server settings." },
		{ "icon16/cog.png", "Settings and rights", "The Player tab of this window has your own settings: language, interface, sounds, the gun's place in the hand. Friends are the players you trust (they see your markers, Meeseeks let them through).\n\nThe other tabs are the server settings by section; only a superadmin can change them. The same is in the spawn menu: Utilities → Rick and Morty." },
	},
}

function RMPG.WikiTab(sheet)
	local list = TOPICS[RMPG.LangCode() == "ru" and "ru" or "en"]
	local p = vgui.Create("DPanel", sheet)
	p.Paint = function(s, w, h)
		surface.SetDrawColor(3, 12, 10, 235)
		surface.DrawRect(0, 0, w, h)
	end
	local left = RMPG.UI.Scroll(p)
	left:Dock(LEFT)
	left:SetWide(230)
	left:DockMargin(8, 8, 4, 8)
	local right = RMPG.UI.Scroll(p)
	right:Dock(FILL)
	right:DockMargin(4, 8, 8, 8)
	local cur = 1
	local icons = {}

	local function Show(i)
		cur = i
		right:Clear()
		local t = list[i]
		local head = vgui.Create("DPanel", right)
		head:Dock(TOP)
		head:SetTall(44)
		head:DockMargin(0, 0, 8, 6)
		icons[t[1]] = icons[t[1]] or Material(t[1])
		head.Paint = function(s, w, h)
			RMPG.HoloBox(0, 0, w, h, Color(6, 30, 20, 230), Color(90, 255, 150))
			surface.SetMaterial(icons[t[1]])
			surface.SetDrawColor(255, 255, 255)
			surface.DrawTexturedRect(12, h / 2 - 8, 16, 16)
			RMPG.HoloText(t[2], "RMPG_Head", 38, h / 2, Color(225, 255, 235), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		end
		local body = vgui.Create("DLabel", right)
		body:Dock(TOP)
		body:DockMargin(6, 0, 14, 10)
		body:SetWrap(true)
		body:SetAutoStretchVertical(true)
		body:SetFont("RMPG_Body")
		body:SetTextColor(Color(205, 240, 220))
		body:SetText(t[3])
	end

	for i, t in ipairs(list) do
		local b = vgui.Create("DButton", left)
		b:Dock(TOP)
		b:SetTall(34)
		b:DockMargin(0, 0, 6, 4)
		b:SetText("")
		icons[t[1]] = icons[t[1]] or Material(t[1])
		b.Paint = function(s, w, h)
			local sel = cur == i
			local fill = sel and Color(24, 96, 62, 235) or (s:IsHovered() and Color(16, 60, 42, 225) or Color(8, 34, 24, 215))
			RMPG.HoloBox(0, 0, w, h, fill, sel and Color(90, 255, 150) or Color(40, 140, 90))
			surface.SetMaterial(icons[t[1]])
			surface.SetDrawColor(255, 255, 255)
			surface.DrawTexturedRect(10, h / 2 - 8, 16, 16)
			draw.SimpleText(t[2], "RMPG_SmallB", 34, h / 2, Color(220, 255, 232), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		end
		b.DoClick = function()
			surface.PlaySound(RMPG.SND.uiClick)
			Show(i)
		end
	end
	Show(1)
	sheet:AddSheet(RMPG.T("wiki_tab"), p, "icon16/book_open.png")
end
