--=============================================================
--2022.02.11-14...02.22..2024.01.21-26
--=============================================================
local market={} market.chest={} market.me={}
market.version='1.10'
local fs=require('filesystem')
local component=require('component')
local gpu=require('component').gpu
local computer=require('computer')
local pullSignal=computer.pullSignal
local event=require('event')
local table=require('table')
local math=require('math')
local port, send = 0xffef, 0xfffe
local serialization=require("serialization")
--local zero, one = 0, 1
local sx,sy= 72,24
local unicode=require('unicode')
local me, pim, selector = {}, {}, {}
local tap,pos,menu = 0,1,'screenInit'
local emptySlot, price = true, 'sell_price'
local inpuStringFlag = false
local findFlag = false
if component.isAvailable('openperipheral_selector') then
  selector = require('component').openperipheral_selector
else selector = {setSlot=function(...) return nil end}
end
if component.isAvailable('pim') then 
  pim=require('component').pim
end
market.workmode='chest'
market.link = 'unlinked'
market.serverAddress = ''
market.msgnum=14041

--лист с полями sell_price, buy_price, qty, display_name, damage и ключом raw_name
market.itemlist = {}--содержит все оценённые предметы магазина
market.chestList = {}--содержит предметы в сундуке связанном с терминалом
market.inumList={} --содержит нумерованный список с айди предметов магазина
market.inventory = {}--содержит список предметов текущего посетителя
market.select='' --raw_name выбранного предмета--на техномагик id предмета
market.mode='trade'
market.chestShop=''--используемый сундук. содержит ссылку на компонет сундук или ме сеть
market.number= '0'--означает число товара в покупке. также поле в установке цен
market.substract =''--содержит число для вычета наличных
market.owner={}
market.shopLine=1
market.selectedLine='1'
market.player={status='player',name='name',uid='uid',balance='0',ban='-',cash='0'}
--получаем название используемого торгового сундука. список сундуков GTImpact модпака
market.component = {'compactchest_inv','neutronium','iridium','osmium','chrome','wolfram','titanium',
'hsla','aluminium','steel','wriron','chest','tile_extrautils_chestfull_name'}

for chest in pairs(market.component)do 
	if component.isAvailable(market.component[chest]) then
		market.chestShop=require('component')[market.component[chest]]
		market.workmode='chest'
	end
end

local modem={broadcast=function(...)end}
if component.isAvailable('modem')then
  modem = require ('component').modem
end
modem.open(port)
modem.setWakeMessage('name')
if component.isAvailable('me_interface') then
	market.chestShop=require('component').me_interface
	market.workmode='me'
	me=market.chestShop
end

market.pimmoney='customnpcs:npcMoney'..'&&'..'0'
market.money='customnpcs:npcMoney'..'&&'..'0'
local money={name='customnpcs:npcMoney',damage='0'}
market.moneyInMarket = 0

--позаимствованная у BrightYC таблица цветов.добавлен мутно-зелёный
local color = {
    pattern = "%[0x(%x%x%x%x%x%x)]",
    background = 0x000000,
    pim = 0x46c8e3,
    gray = 0x303030,
    lightGray = 0x999999,
    blackGray = 0x1a1a1a,
    lime = 0x68f029,
    greengray = 0x0bde31,
    blackLime = 0x4cb01e,
    orange = 0xf2b233,
    blackOrange = 0xc49029,
    blue = 0x4260f5,
    blackBlue = 0x273ba1,
    red = 0xff0000
}
--список перехватываемых событий
market.events={player_on='pimWho',player_off='pimByeBye',touch='screenDriver',modem_message='serverResponse'}
market.screen={}--лист для функциональных кнопок экрана. остальные выводятся сбросом листа их названий в market.place
--содержит все используемые кнопки. Кнопки содержат поля: координаты x y,
--размер по x y, текст, внутренняя позиция текста, цвета
market.button={
	eula1={x=5,xs=67,y=3,ys=1,text='Здравствуйте! Рады видеть вас!',tx=1,ty=0,bg=0x303030,fg=0x68f029},
	eula2={x=5,xs=67,y=5,ys=1,text='Вас приветствует электронный магазин ПимМаркет.',tx=1,ty=0,bg=0x303030,fg=0x68f029},
	eula3={x=5,xs=67,y=7,ys=1,text='Все покупки в магазине производятся за НПЦ мани.',tx=1,ty=0,bg=0x303030,fg=0x68f029},
	eula4={x=5,xs=67,y=9,ys=1,text='Обменник эмов на НПЦ мани стоит на спавне -',tx=1,ty=0,bg=0x303030,fg=0x68f029},
	eula5={x=5,xs=67,y=11,ys=1,text='сдача от покупки зачислится на Пим-счёт игрока.',tx=1,ty=0,bg=0x303030,fg=0x68f029},
	eula6={x=5,xs=67,y=13,ys=1,text='Этот счёт автоматически используется при последующих покупках.',tx=1,ty=0,bg=0x303030,fg=0x68f029},
	eula7={x=5,xs=67,y=15,ys=1,text='Все цены в магазине указаны в Эмах.',tx=1,ty=0,bg=0x303030,fg=0x68f029},
	eula9={x=5,xs=67,y=19,ys=1,text='Если вы согласны с предоставленными условиями пользования',tx=1,ty=0,bg=0x303030,fg=0x68f029},
	eula10={x=5,xs=67,y=21,ys=1,text='подтвердите согласием',tx=1,ty=0,bg=0x303030,fg=0x68f029},
	eula11={x=30,xs=19,y=24,ys=1,text='СОГЛАСЕН/СОГЛАСНА',tx=1,ty=0,bg=0xf2b233,fg=0x111111},
	eula12={x=51,xs=26,y=24,ys=1,text='discord автора:taoshi#2664',tx=0,ty=0,bg=0x103010,fg=0xf2b233},
	eula13={x=1,xs=28,y=23,ys=1,text='по всем вопросам о товаре',tx=0,ty=0,bg=0x103010,fg=0xf2b233},
	eula14={x=1,xs=28,y=24,ys=1,text='пишите владельцу варпа',tx=0,ty=0,bg=0x103010,fg=0xf2b233},

	player={x=3,xs=10,y=1,ys=1,text='name',tx=1,ty=0,bg=0x303030,fg=0x68f029},
	status={x=3,xs=10,y=2,ys=1,text='player',tx=1,ty=0,bg=0x303030,fg=0x68f029},
	mode={x=3,xs=10,y=3,ys=1,text='trade',tx=1,ty=0,bg=0x303030,fg=0x68f029},
	totalitems={x=1,xs=19,y=24,ys=1,text=tostring(#market.inumList)..'items',tx=1,ty=0,bg=0x303030,fg=0x68f029},
	cashname={x=3,xs=10,y=5,ys=1,text='НПЦ монеты',tx=0,ty=0,bg=0x303030,fg=0x68f029},
	cash={x=3,xs=10,y=6,ys=1,text='NPC money:',tx=0,ty=0,bg=0x303030,fg=0x68f029},
	balancename={x=3,xs=10,y=7,ys=1,text='ПИМ-мани:',tx=0,ty=0,bg=0x303030,fg=0x68f029},
	balance={x=3,xs=10,y=8,ys=1,text='lua coins:',tx=0,ty=0,bg=0x303030,fg=0x68f029},

	one={x=17,xs=6,y=4,ys=3,text='1',tx=2,ty=1,bg=0x303030,fg=0x68f029},
	two={x=25,xs=6,y=4,ys=3,text='2',tx=2,ty=1,bg=0x303030,fg=0x68f029},
	free={x=33,xs=6,y=4,ys=3,text='3',tx=2,ty=1,bg=0x303030,fg=0x68f029},
	foo={x=17,xs=6,y=8,ys=3,text='4',tx=2,ty=1,bg=0x303030,fg=0x68f029},
	five={x=25,xs=6,y=8,ys=3,text='5',tx=2,ty=1,bg=0x303030,fg=0x68f029},
	six={x=33,xs=6,y=8,ys=3,text='6',tx=2,ty=1,bg=0x303030,fg=0x68f029},
	seven={x=17,xs=6,y=12,ys=3,text='7',tx=2,ty=1,bg=0x303030,fg=0x68f029},
	eight={x=25,xs=6,y=12,ys=3,text='8',tx=2,ty=1,bg=0x303030,fg=0x68f029},
	nine={x=33,xs=6,y=12,ys=3,text='9',tx=2,ty=1,bg=0x303030,fg=0x68f029},
	zero={x=25,xs=6,y=16,ys=3,text='0',tx=2,ty=1,bg=0x303030,fg=0x68f029},
	back={x=17,xs=6,y=16,ys=3,text='<-',tx=2,ty=1,bg=0x303030,fg=0x68f029},
	dot={x=33,xs=6,y=16,ys=3,text='.',tx=2,ty=1,bg=0x303030,fg=0x68f029},
	ok={x=33,xs=6,y=16,ys=3,text='OK',tx=2,ty=1,bg=0x303030,fg=0x68f029},
	set={x=41,xs=6,y=16,ys=3,text='ok',tx=2,ty=1,bg=0x303030,fg=0x68f029},

	number={x=41,xs=12,y=8,ys=3,text='',tx=10,ty=1,bg=0x303030,fg=0x68f029},
	select={x=41,xs=24,y=4,ys=3,text='item',tx=2,ty=1,bg=0x303030,fg=0x68f029},
	totalprice={x=41,xs=12,y=12,ys=3,text='',tx=2,ty=1,bg=0x303030,fg=0x68f029},
	incorrect={x=41,xs=20,y=12,ys=3,text='нeхватка срeдств',tx=2,ty=1,bg=0x303030,fg=0x68f029},
	buyCancel={x=12,xs=45,y=10,ys=3,text='Извинитe, товар кончился. Вычтeнныe срeдства возвращeны',tx=2,ty=1,bg=0x303030,fg=0x68f029},
	sellCancel={x=12,xs=45,y=10,ys=3,text='У нас денег стoлькo нeт. Toвары вoзвращeны',tx=2,ty=1,bg=0x303030,fg=0x68f029},


	newname={x=26,xs=4,y=16,ys=3,text='newname',tx=2,ty=1,bg=0x303030,fg=0x68f029},
	acceptbuy={x=41,xs=26,y=16,ys=3,text='подтвердить',tx=7,ty=1,bg=0x303030,fg=0x68f029},
	acceptSell={x=41,xs=26,y=16,ys=3,text='подтверждаю',tx=7,ty=1,bg=0x303030,fg=0x68f029},
	
	cancel={x=34,xs=10,y=24,ys=1,text='назад',tx=2,ty=0,bg=0x303030,fg=0x68f029},
	find={x=48,xs=10,y=24,ys=1,text='поиск:',tx=2,ty=0,bg=0x303030,fg=0x68f029},
	findInput={x=60,xs=10,y=24,ys=1,text='',tx=2,ty=0,bg=0x303030,fg=0x28f029},

	welcome={x=24,xs=32,y=12,ys=3,text='добро пожаловать в ПимМаркет',tx=2,ty=1,bg=0x303030,fg=0x68f029},
	name={x=32,xs=24,y=8,ys=3,text='name',tx=2,ty=1,bg=0x303030,fg=0x68f029},
	wait={x=27,xs=24,y=16,ys=3,text='ждём ответ сервера...',tx=2,ty=1,bg=0x303030,fg=0x68f029},
	entrance={x=3,xs=72,y=2,ys=22,text='',tx=1,ty=1,bg=0x141414,fg=color.blackLime},
	pim1={x=26,xs=24,y=6,ys=12,text='',tx=1,ty=1,bg=0x404040,fg=0x68f029},
	pim2={x=28,xs=20,y=7,ys=10,text='Встаньте на PIM',tx=2,ty=4,bg=0x202020,fg=0x68f029},
	buy={x=30,xs=16,y=8,ys=3,text='Купить',tx=5,ty=1,bg=0x303030,fg=0x68f029},
	sell={x=30,xs=16,y=12,ys=3,text='Продать',tx=5,ty=1,bg=0x303030,fg=0x68f029},
	full={x=16,xs=39,y=10,ys=3,text='Ваш инвентарь полон. Доступ закрыт.',tx=2,ty=1,bg=0x303030,fg=0x68f029},
	transfer={x=23,xs=30,y=16,ys=3,text='Перевод другому игроку',tx=4,ty=1,bg=0x303030,fg=0x68f029},

	transfer_name={x=24,xs=28,y=10,ys=3,text='Введите имя для перевода',tx=2,ty=1,bg=0x303030,fg=0x68f029},
	transfer_value={x=25,xs=26,y=10,ys=3,text='Введите сумму перевода',tx=2,ty=1,bg=0x303030,fg=0x68f029},
	transfer_not_registered={x=28,xs=26,y=18,ys=3,text='Нет в базе данных',tx=5,ty=1,bg=0x303030,fg=0x68f029},
	transfer_tooBig={x=28,xs=19,y=18,ys=3,text='У вас нет столько',tx=2,ty=1,bg=0x303030,fg=0x68f029},
	transfer_complite={x=29,xs=20,y=18,ys=3,text='Перевод завершён',tx=2,ty=1,bg=0x303030,fg=0x68f029},

	sell_mode={x=3,xs=10,y=10,ys=1,text='Покупка',tx=1,ty=0,bg=0x303030,fg=0x68f029},
	buy_mode={x=3,xs=10,y=10,ys=1,text='Продажа',tx=1,ty=0,bg=0x303030,fg=0x68f029},
	shopUp={x=3,xs=10,y=12,ys=5,text='ВВЕРХ',tx=2,ty=2,bg=0x303030,fg=0x68f029},
	shopDown={x=3,xs=10,y=18,ys=5,text='ВНИЗ',tx=3,ty=2,bg=0x303030,fg=0x68f029},
	shopTopRight={x=21,xs=55,y=1,ys=1,text='Available items                           к-во     цена',tx=0,ty=0,bg=0xc49029,fg=0x000000},
	shopFillRight={x=21,xs=40,y=2,ys=21,text='',tx=0,ty=0,bg=0x303030,fg=0x68f029},
	shopVert={x=68,xs=1,y=2,ys=21,text=' ',tx=0,ty=0,bg=0xc49029,fg=0x111111},
	attention={x=1,xs=80,y=1,ys=23,text='Ваше поведение возмутительно! Прощаемся!!!',tx=23,ty=12,bg=0x33ff00,fg=0xff0033}
}

--это обработчик экрана.
--содержит все функции вызываемые кнопками
--в том числе меняющие содержимое экрана
market.screenActions={}
market.screenActions.find=function()return market.find() end
market.screenActions.eula11=function()return market.mainMenu() end
market.screenActions.sell=function() price = 'buy_price' return market.inShopMenu() end----игрок продаёт
market.screenActions.buy=function() price = 'sell_price' if emptySlot then  return market.inShopMenu()end end
market.screenActions.transfer=function()return market.transfer()end
market.screenActions.transfer_not_registered=function()return market.transfer()end
market.screenActions.transfer_tooBig=function()return market.transferValue()end
market.screenActions.transfer_complite=function()return market.mainMenu()end
market.screenActions.one=function()market.number=market.number..'1' return market.inputNumber(1) end
market.screenActions.two=function()market.number=market.number..'2' return market.inputNumber(2) end
market.screenActions.free=function()market.number=market.number..'3' return market.inputNumber(3) end
market.screenActions.foo=function()market.number=market.number..'4' return market.inputNumber(4) end
market.screenActions.five=function()market.number=market.number..'5' return market.inputNumber(5) end
market.screenActions.six=function()market.number=market.number..'6' return market.inputNumber(6) end
market.screenActions.seven=function()market.number=market.number..'7' return market.inputNumber(7) end
market.screenActions.eight=function()market.number=market.number..'8' return market.inputNumber(8) end
market.screenActions.nine=function()market.number=market.number..'9' return market.inputNumber(9) end
market.screenActions.zero=function()market.number=market.number..'0' return market.inputNumber(0) end
market.screenActions.dot=function()market.number=market.number..'.' return market.inputNumber('.')end
market.screenActions.back=function()if #market.number > 0 then
	market.number=string.sub(market.number,1,#market.number-1) return market.inputNumber('-') end end
market.screenActions.ok=function() return market.inputNumber('ok')  end
market.screenActions.acceptbuy=function() return market.getNewBalance() end
market.screenActions.acceptSell=function()return market.playerSell () end
--================================================================
market.screenActions.shopTopRight=function() end
market.screenActions.shopVert=function() end
market.screenActions.shopUp=function() if market.shopLine > 15 then
	market.shopLine=market.shopLine-15 end return market.showMeYourCandyesBaby(market.itemlist,market.inumList) end
market.screenActions.shopDown=function() if market.itemlist.size-15 > market.shopLine then
	market.shopLine=market.shopLine+15 end return market.showMeYourCandyesBaby(market.itemlist,market.inumList) end
  
market.screenActions.shopFillRight=function(_,y)--ловит выбор игроком предмета
	market.selectedLine = y+market.shopLine-2
  
  local idx = market.lot[y]
  if not idx then return end
  
	if market.selectedLine <= #market.inumList then
	market.select=market.inumList[market.lot[y]]
  selector.setSlot(1,{id=market.itemlist[market.select].name,dmg=market.itemlist[market.select].damage})
      tap = tap+1
      if tap == 1 then
        return market.userSelect(y)
      elseif pos ~= math.floor(y) then
        market.select=market.inumList[market.lot[pos]]
        tap = 1
        market.userSelect(pos,color.blackLime)
        market.select=market.inumList[market.lot[y]]
        return market.userSelect(y)
      end
  tap = 0
	market.button.select.text=market.itemlist[market.select].display_name
	market.button.select.xs=#market.itemlist[market.select].display_name+4
  if market.mode == 'find' then return market.trade(market.selectedLine) end
	return market[market.mode](market.selectedLine)
	end
end

market.userSelect=function(y,color)
  pos = math.floor(y)
  color = color or 0xf800f8
  --gpu.setActiveBuffer(zero)
  gpu.setForeground(color)
  gpu.set(21,pos,market.itemlist[market.select].display_name)
  --gpu.setActiveBuffer(one)
  return true
end

market.screenActions.set = function()return market.inputNumber('set') end
market.screenActions.cancel = function()
  tap = 0
  market.key = nil
	market.number = '0'
	market.totalprice = 0
	market.button.number.text = '0'
	market.button.totalprice.text = '0'
  selector.setSlot(1,nil)
  if menu == 'trade' then return market.inShopMenu()
  elseif menu == 'inShopMenu' then return market.mainMenu()
  else end
  return market.mainMenu()
  
end
--====================================================================================
market.screenActions.status=function()
	if market.player.status=='owner' then
		if market.mode=='trade' then market.mode = 'edit'	
		else 
			if market.mode == 'edit' then market.mode = 'rename'
			else
				market.mode = 'trade'
			end
		end
	else 
		market.mode = 'trade'	
	end
	market.button.mode.text=market.mode
	return market.place({'mode'})
end
--================================================================
market.mainMenu=function()
  menu='main'
	market.screen={'sell','buy','transfer'}
	return market.replace()
end

--вызов меню набора номера.
market.trade=function()
  menu='trade'
	market.screen={'status','one','two','free','foo','five','six','seven','eight',
	'nine','zero','back','ok','cancel'}
	market.replace()
	return market.place({'mode','number','select','totalprice','balancename','balance','cash','cashname','player'})
end

--меню владельца для ввода цены
market.edit=function()
	market.screen={'status','one','two','free','foo','five','six','seven','eight',
	'nine','zero','back','set','dot','cancel'}
	market.replace()
	return market.place({'mode','number','select','balance','cash','cashname','player'})
end

--меню владельца для наименования
market.rename=function()
	market.clear(0x202020)
	market.place({'select','newname'})
	market.screen={}
	market.itemlist[market.inumList[line]].display_name = market.inputString()
	market.save_toFile(market.itemlist)
	return market.inShopMenu()
end


--меню посетителя для поиска
market.find = function()
findflag = true
  --market.screen={'status','shopUp','shopDown','shopFillRight','cancel','find'}
  market.place({'findInput'})
  local pmode = market.mode
  market.mode = 'find'
	market.key = market.inputString()
  market.mode = pmode
  market.button.findInput.text = market.key
  market.key = nil
  findflag = false
	return true -- market.inShopMenu()
end

market.inputString=function()
inpuStringFlag = true
	local name=''
	--if market.mode ~= 'find' and market.player.status ~= 'owner' then return true end
	while inpuStringFlag do
		local _,_,ch,scd = event.pull('key_down')
		if ch then
			if ch>30 then 
				name=name..unicode.char(ch)
			end

			if ch == 8 then name=string.sub(name,1,#name-1) end
			if ch==0 and scd==211 then name=string.sub(name,1,#name-1) end
			if ch==13 then inpuStringFlag = false end
      market.button.newname.text=name..' '
      market.button.newname.xs=#name+4
      if market.mode ~= 'find' and market.mode ~='trade' then 
      	market.place({'newname'})
      else market.key = name market.button.findInput.text = market.key
        market.showMeYourCandyesBaby(market.itemlist,market.inumList)
        market.place({'findInput'})
      end
    end
    
	end
	market.button.newname.text=''
	market.button.newname.xs=2
	inpuStringFlag = false
	return name 
end

--скромно перерисовывает поле цифрового ввода и следит за ним
market.inputNumber=function(op)
	if op == 'set' then return market.setPrice() end
	if op == 'ok' then 
		if price == 'sell_price' then
			return market.acceptBuy() 
		else 
			return market.acceptBuyFromPlayer() 
		end
	end

	if market.mode == 'trade' then
		if tonumber(market.number) and tonumber(market.number)> market.itemlist[market.select].qty then
				market.number = tostring(market.itemlist[market.select].qty)
		end
		if #market.number > 5 then
			if tonumber(market.number) and tonumber(market.number) > 999 then
				market.number = tostring(math.floor(999))
			end	
		end
	end
	market.button.number.text = market.number..' '
	market.button.number.xs = #market.itemlist[market.select].display_name+4
	market.button.number.tx =
	(#market.itemlist[market.select].display_name+4)/2-#market.button.number.text/2
	local items= tonumber(market.number) or 0
	local count= tonumber(market.itemlist[market.select][price]) or 0
	market.items = items 
	market.count = count
	market.totalprice = items * count
	market.button.totalprice.text = tostring(market.totalprice) .. '   '
	market.button.totalprice.xs = #market.itemlist[market.select].display_name+4
	market.button.totalprice.tx = 
	(#market.itemlist[market.select].display_name+4)/2-#market.button.totalprice.text/2
	if market.mode == 'trade' then return market.place({'number','totalprice'}) end
	return market.place({'number'})
end

--обновляет состояние инвентаря, пишет кеш и баланс
market.updateMoney=function()
	market.player.cash=market.findCash()
	market.button.cash.text=tostring(math.floor(market.player.cash))
	market.button.balance.text=tostring(market.player.balance)
	return true 
end

--проверяет есть ли у покупателя чем расплатиться
market.checkPlayerMoney=function()
	return tonumber(market.player.cash) + tonumber(market.player.balance)
	>= tonumber(market.button.totalprice.text)
end

--запрашивает подтверждение выбора с указанием количества
--осуществляет вызов продажи
market.acceptBuy=function()
	if not market.checkPlayerMoney() then return true end		
	market.screen={'acceptbuy','buyCancel','cancel'}
	return market.place({'acceptbuy'})
end

market.acceptBuyFromPlayer=function()
	--if math.huge then return true end --
	market.screen={'acceptSell','sellCancel','cancel'}--
	return market.place({'acceptSell'})
end



--на основе объёма покупки производим действия с балансом
--эта функция нам важна при покупке игроком товара
--но как быть если посетитель сам продаёт товар
market.getNewBalance=function()
	market.inventory = market.chest.get_inventoryitemlist(pim)
	market.updateMoney()
	local totalprice = market.totalprice
	if not market.checkPlayerMoney() then --поже, нас пытались обмануть.
		market.replace({'attention'})
		os.sleep(2)
		return market.inShopMenu()
	end
	local balance = tonumber(market.player.balance)
	if balance > 0 then
		--если баланс не ниже суммы покупки
		if balance >= totalprice then
				market.substract = 0
				market.balanceOP=totalprice
			else --баланс ниже суммы покупки, но не 0
				--число монет к изъятию
				market.substract = math.floor(totalprice-balance)+1
				--сумма вычета с баланса
				market.balanceOP = totalprice-market.substract
		end
	else--если баланс 0, то он не может стать меньше!
		market.substract = math.floor(totalprice)+1
		--для автозачисления сдачи на баланс
		market.balanceOP = totalprice-market.substract
	end
	local msg = {name=market.player.name,op='buy',number=market.msgnum,value=market.balanceOP}
	return market.serverPost(msg)			
end
--================================
market.playerSell = function()
   market.clear() -- Очистка интерфейса

  -- 1. Проверка выбранного предмета
  local id = market.select
  if not id then
    print("ОШИБКА: Не выбран предмет для продажи")os.sleep(2)
    market.replace({'error_no_item_selected'})
    
    return market.inShopMenu()
  end

  -- 2. Получение параметров предмета
  market.itemData = market.itemlist[id]
  if not market.itemData then
    print("ОШИБКА: Нет данных о предмете в itemlist")os.sleep(2)
    market.replace({'error_item_not_found'})
    
    return market.inShopMenu()
  end

  local damage = market.itemData.damage or '0'
  local price = market.itemData.buy_price or 0 -- Используем цену скупки

  -- 3. Обработка количества
  local count = tonumber(market.number)
  if not count or count <= 0 then
    print("ОШИБКА: Некорректное количество:", market.number)
    os.sleep(2)
    market.replace({'error_invalid_count'})
    
    return market.inShopMenu()
  end
-----------------------------------------
  -- 4. Проверка наличия предметов у игрока
  local playerItemCount = 0
  market.inventory = market.chest.get_inventoryitemlist(pim)
  if market.inventory[id] then
    playerItemCount = market.inventory[id].qty
  end

  if playerItemCount < count then
    print(string.format("ОШИБКА: У игрока %d/%d предметов", playerItemCount, count))
    market.replace({'not_enough_items'})
    os.sleep(2)
    return market.inShopMenu()
  end
----------------------------------------
  -- 5. Логирование параметров для отладки
  --print(string.format("Продажа: %s x%d (damage: %d) за %d монет", 
  --  id, count, damage, price * count))

  -- 6. Удаление предметов из инвентаря игрока (device,id,count, op)
  local success, reason = market.chest.fromInvToInv(
    pim,        -- Инвентарь игрока
    id,         -- ID предмета формата "minecraft:diamond&&0"
    count,      -- Количество
    'pushItem' -- Операция (от игрока в магазин)
  )

  if not success then
    print("ОШИБКА: Не удалось удалить предметы:", reason)os.sleep(2)
    market.replace({'error_removing_items'})
    
    return market.inShopMenu()
  end


  -- 7. Выдача денег игроку 
  local totalMoney = price * count
  local msg = {name=market.player.name,op='sell',number=market.msgnum,value=totalMoney}
	return market.serverPost(msg)
end
--==================================================--
--завершает продажу. забирает валюту. выдаёт предметы
market.finalizeBuy=function()
	market.clear()
	--число монет к изъятию
	local price = market.substract
	--пушим в сундук монеты = оплата покупки
	market.chest.fromInvToInv(pim,market.money,price,'pushItem')

	local id=market.select--рав-имя предмета
  local damage=market.itemlist[id].damage
  local count = 0
  if tonumber(market.number) then count = tonumber(market.number) end
	--пуллим из сундука = выдача товара
	market[market.workmode].fromInvToInv(market.chestShop,id,count,'pullItem',price,damage)

	market.itemlist[id].qty=market.itemlist[id].qty - count
	return market.inShopMenu()
end

--==================================================--
-- Основная функция завершения продажи
market.finalizeSell = function()
 

  --[[local moneySuccess = market[market.workmode].fromInvToInv(
    market.chestShop, -- Инвентарь магазина
    market.money,     -- ID валюты
    totalMoney,       -- Сумма
    'pullItem'        -- Операция (из магазина игроку)
  )]]
            --(_,id,count, _, price,damage)
  --[[local moneySuccess = market[market.workmode].fromInvToInv(
  	0,market.money,totalMoney,0,price,damage)

  if not moneySuccess then
    -- Откат операции: возвращаем предметы
    market.chest.fromInvToInv(
      market.chestShop,
      id,
      count,
      'pullItem',
      damage
    )
    
    print("ОШИБКА: Не удалось выдать деньги")os.sleep(2)
    market.replace({'error_giving_money'})
    
    return market.inShopMenu()
  end]]
  -- 8. Обновление данных магазина
  
  local count = tonumber(market.number) or 0
  market.itemData.qty = (market.itemData.qty or 0) + count
  market.inventory = market.chest.get_inventoryitemlist(pim)
  market.updateMoney()
  -- 9. Успешное завершение
  --print("Продажа успешно завершена!")
  --market.replace({'transaction_success'})
  --os.sleep(1)
  return market.inShopMenu()
end


--завершает сессию установки цены овнером
market.setPrice = function()
	market.itemlist[market.select][price] = market.number
	market.save_toFile(market.itemlist)
	return market.inShopMenu()
end

--проверка наличия аккаунта. 
function market.isRegistered(bool)
	market.clear(0x202020)
	if not bool then
		market.screen={'transfer_not_registered','cancel'}
		return market.replace()
	end
	return market.transferValue()
end
--завершение трансфера. вывод уведомления
function market.transferComplite()
	market.screen={'transfer_complite'}
	return market.replace()
end
--меню трансфера
market.transfer=function()
	market.clear(0x202020)
	market.place({'transfer_name','newname','cancel'})
	market.screen={'cancel'}
	market.select = market.inputString()
	local msg={name=market.player.name,name2=market.select,op='isRegistered',number=market.msgnum,value='0'}
	return market.serverPost(msg)
end
market.transferValue=function()
	market.clear(0x202020)
	market.place({'transfer_value','newname','cancel'})
	market.screen={'cancel'}
	market.number ='not number'
	while not tonumber(market.number) do
		market.number = market.inputString()
	end
	if tonumber(market.player.balance) >= tonumber(market.number) then
		local msg={name=market.player.name,name2=market.select,op='transfer',number=market.msgnum,value=market.number}
		return market.serverPost(msg)   --market.inShopMenu()
	else
		market.screen = {'transfer_tooBig','cancel'}
		return market.replace()
	end
end
--==================================================================
--pim & chest - components contains inventory
--inventoryList - itemlist of csanning inventory
--item_raw_name, count - raw name of item and count for migrate
--op - type of operation in string format. itemPull or itemPush
--device - определяет проверяемый инвентарь
--передаёт выбранный предмет itemid в количестве count из целевого в назначенный инвентарь
--параметр передачи задаётся агр. 'op'=itemPull or itemPush
function market.chest.fromInvToInv(device,id,count, op)--, damage)
  --параметр damage присутствует  полученном поле id
  --print('ищем в инвентаре ' .. id) os.sleep(2)
	local c, legalSlots=count, {}
	local inventory=device.getAllStacks()
	for pos,slot in pairs(inventory) do
    local stack = slot.all()
    --print('slot'..pos ..' find .. ' ..stack.id ) os.sleep(1)
    local damage = 'damage'
    if not stack[damage] then damage = 'dmg' end
    local dmg = tostring(math.floor(stack[damage]))
		if id == stack.id..'&&'..dmg then
      --print('мы нашли это!') os.sleep(2)
			table.insert(legalSlots, pos)
		end
	end

	for slot in pairs(legalSlots)do
		local currentItem = device.getStackInSlot(legalSlots[slot])
		local available=currentItem.qty
		if c > 0 then
			if c > available then
				c=c-available
				pim[op]('down',legalSlots[slot],available)--из слота в назначение
			else
				pim[op]('down',legalSlots[slot],c)--остатки меньше стака
				c=0
			end
		end
	end
	return true
end

function market.buyCancel(price)
	market.me.fromInvToInv(me, market.money, price)
	market.screen={'buyCancel','cancel'}
	return market.replace()
end

--!!!эта функция только выдаёт предметы!!!
function market.me.fromInvToInv(_,id,count, _, price,damage)
  local c=count or 0
	local item=market.me.getItemDetail(id,damage)
  --а что если нехватает затребованной клиентом позиции?
	if not item or item.size < count then --предметы кончились. отмена покупки
		return market.buyCancel(price) --штош... приходитя пожжее
	end
	local fp={id=item.name,dmg=item.damage}
	while c > 0 do
		if c > item.maxSize then
			c=c-item.maxSize
			me.exportItem(fp,'up',item.maxSize)
		else
			me.exportItem(fp,'up',c)
			c=0	
		end
	end
	return true
end
--поиск требуемого предмета в ме хранилище
function market.me.getItemDetail(id,damage)
	local damage = damage or '0'
  local name=string.gsub(id,'&&'..damage,'')
	local item=me.getItemsInNetwork({name=name,damage=damage})[1]
  return item
end

function market.findCash()
	local cash, slots = 0, 0
	if market.inventory[market.pimmoney] then
		cash = market.inventory[market.pimmoney].qty
		slots = market.inventory[market.pimmoney].slots
	end
	return cash,slots
end
--=============================================================
--displayet items availabled for trading
--отрисовывает доступные товары
function market.showMeYourCandyesBaby(itemlist,inumList)--()--
  --local itemlist = market.itemlist
  --local inumList = market.inumList
  local skipped_items = 0
  tap = 0
  selector.setSlot(1,nil)
	local pos=market.shopLine
	local total=#inumList
	local qty=0
	market.lot={}
  local y=2
  local filter =  market.key and tostring(market.key):lower() or ''
	--поиск предметов с к-вом больше чем 1
	while pos <= total do
		local item=inumList[pos]
    local show = true
    if filter ~= '' then 
      if not itemlist[item].display_name:lower():find(filter,1,true) then
        show = false
        skipped_items = skipped_items + 1
      end
    end
    
		if itemlist[item] and tonumber(itemlist[item].qty) > 0 and show then
			market.lot[y]=pos
			y=y+1
		end
		pos=pos+1
		if y > 23 then pos=total+1 end
	end

	--gpu.setActiveBuffer(zero)
	gpu.setBackground(0x111111)
	gpu.setForeground(color.blackLime)
	gpu.fill(21,2,42,21,' ')
	gpu.fill(64,2,5,21,' ')
	gpu.fill(72,2,5,21,' ')

	y=2
	while y < 23 do
		local item=inumList[market.lot[y]]
    if itemlist[item] then
		qty=tostring(math.floor(tonumber(itemlist[item].qty)))
		gpu.set(21,y,itemlist[item].display_name)
		gpu.set(64,y,qty)
		gpu.set(72,y,tostring(itemlist[item][price]))
    end
		y=y+2
	end

	gpu.setBackground(0x252525)
	y=3
	while y < 23 do
		local item=inumList[market.lot[y]]
    if itemlist[item] then
		qty=tostring(math.floor(tonumber(itemlist[item].qty)))
		gpu.set(21,y,"                                                       ")
		gpu.set(21,y,itemlist[item].display_name)
		gpu.set(64,y,qty)
		gpu.set(72,y,tostring(itemlist[item][price]))
    end
		y=y+2
	end

	--gpu.setActiveBuffer(one)
	return true
end

market.isPlayerInventoryFull=function()
	emptySlot = false
	for slot = 1,36 do
		if not pim.getStackInSlot(slot) then emptySlot = true end
	end
	return true
end

--обновим список предметов в МЕ
market.itemListReplace=function()
	market.inumList={}
	market.chestList=market[market.workmode].get_inventoryitemlist(market.chestShop)
	market.merge()
	market.sort()
end

--отрисовывает поля меню выбора товара--------------
market.inShopMenu=function() --попадает сюда при выборе "купить" / "продать"
  menu='inShopMenu'
	--заглядываем в инвентарь игрока. просто любопытство, не более
	market.inventory = market.chest.get_inventoryitemlist(pim)
	--проверка на наличие свободных слотов у покупателя. если их нет - прощаемся
	market.isPlayerInventoryFull()
	--обновляем список товаров в магазине
	market.itemListReplace()
	--убираем из списка то, что не хотим показывать в списке товаров. Это либо нпц мани, либо аналогичный предмет
	for n in pairs (market.inumList) do
		-----------------------------------------------------этот GT предмет не отображается-----
		--if market.itemlist[market.inumList[n]].display_name=='gt.blockmetal4.12.name' then table.remove(market.inumList, n) end
 		if market.itemlist[market.inumList[n]].name==money.name then table.remove(market.inumList, n) end
 		-------------------------предметы с количеством меньше 2х не отображаются-------------
 		---а надо ли плюс 2е переменные - minNUmToBuy maxNumToSell ?
    if market.itemlist[market.inumList[n]].qty < 2 then table.remove(market.inumList, n) end
  end
	market.number=''
	market.button.number.text=''
	
	--находим наличку в инвентаре игрока
	market.updateMoney()
	market.button.totalprice.text='0'
	market.button.totalitems.text=#market.inumList..' type of items available'
	market.screen={'status','shopUp','shopDown','shopFillRight','cancel','find'}
	market.replace()
	market.place({'shopVert','shopTopRight','mode','totalitems','balancename','balance','cash','cashname','player'})
	if price == 'buy_price' then market.place({'buy_mode'}) else market.place({'sell_mode'}) end
	return market.showMeYourCandyesBaby(market.itemlist,market.inumList)
end
--если инвентарь игрока полон-------------------------------
market.full=function()
	market.clear()
	return market.place({'full'})
end
--===============================================
--==--==--==--==--==--==--==--==--==--==--==--
--сюда попадаем получая эвент  touch
--эта функция обрабатывает касания экрана.
--ориентируясь по списку в листе market.screen
--вызывает одноименный кнопке метод в том случае,
--если имя в эвенте совпадает с именем инвентаря на пим
function market.screenDriver(e)
	local x,y,name = e[3],e[4],e[6]
	if name == market.player.name then
		for f,string in pairs (market.screen) do
			local button=market.button[string]
			local a=(x >= button.x and x <= (button.xs+button.x-1)) and (y >= (button.y) and y <= (button.ys+button.y-1))
			if a then
				return market.screenActions[market.screen[f]](x,y)
			end
		end
	end
end
--==--==--==--==--==--==--==--==--==--==--==--
--сюда попадает получая эвент player_on
function market.pimWho(e)
	--=================================
	local who,uid=e[2],e[3]
	market.events.touch='screenDriver'
	market.events.player_on=nil
	market.events.player_off='pimByeBye'
	market.mode='trade'

	market.player.name=who
	market.player.uid=uid
	market.player.status = 'player'
	for f=1, #market.owner do
		if market.owner[f].UUID==uid and market.owner[f].name==who then 
			market.player.status = 'owner'
		end
	end
	
	market.button.status.text=market.player.status
	market.button.player.text=market.player.name
	market.money = market.pimmoney
  market.key = ''

	--здороваемся
	market.button.name.text=who
	market.button.name.xs=#who+4
	market.button.name.x=36-#who/2
	market.clear()
	market.place({'welcome','name','wait'})
	--os.sleep(1)
	--делаем запрос баланса на сервер
	local msg={name=market.player.name,op='enter',number=market.msgnum,value='0'}
	return market.serverPost(msg)
end

--очистка и создание экрана ожидания
--сюда попадаем получая эвент player_off
function market.pimByeBye()
	market.key = ''
	market.events.touch = nil
	market.events.player_off = nil
	market.events.player_on = 'pimWho'
	--market.button.findInput.text=''
	--market.button.newname.text=''

      --market.place({'newname'})
       -- market.place({'findInput'})
      
	--market.button.newname.text=''
	--market.button.newname.xs=2
	market.button.findInput.text = ''
	inpuStringFlag = false
	market.mode = 'trade'
	market.button.mode.text='trade'
	market.player = {}
	market.inventory = {}
	market.screen = {}
	market.place({})
	market.shopLine = 1
  selector.setSlot(1,nil)
	return market.screenInit()
end
--=============================================================
--сортируем лист в алфавитном порядке
function market.sort()
	local index=#market.inumList 
	local pos=1
	while index > pos do
		for int = index, pos, -1 do
			if market.inumList[int] < market.inumList[pos] then
				market.inumList[pos], market.inumList[int] = market.inumList[int], market.inumList[pos]
			end
			if market.inumList[int] > market.inumList[index] then
				market.inumList[index], market.inumList[int] = market.inumList[int], market.inumList[index]
			end
		end
		index=index-1
		pos=pos+1
	end
end
--подшивает актульный список предметов к основному
function market.merge()
	local index,size=1,market.chestList.size
	market.chestList.size=nil
	if not market.itemlist.size then market.itemlist.size=0 end
	for id in pairs(market.chestList) do
		market.inumList[index]=id
		if type (market.itemlist[id]) == 'number' then do end
  else
      
			if not market.itemlist[id] then
				market.itemlist[id]={}
        market.itemlist[id].display_name = market.chestList[id].display_name
        market.itemlist[id].name = market.chestList[id].name
        market.itemlist[id].damage = market.chestList[id].damage
				market.itemlist[id].sell_price = '9999'
				market.itemlist[id].buy_price = '0'	
        
				--уменьшает к-во указанное в таблице на 1 относительно фактического к-ва предметов
				market.itemlist.size=market.itemlist.size+1
			end
      
      market.itemlist[id].qty=market.chestList[id].qty-1
      market.itemlist[id].slots=market.chestList[id].slots
		end
		index=index+1
	end
	market.chestList.size=size
end
--=================================================
--scan inventory. return items table.
--из самостоятельной одноцелевой в многоцелевую
--на вход подать используемый компонент: пим или сундук.
function market.chest.get_inventoryitemlist(device)
	local inventory={}
	inventory.size=0
	local item=''
  
  local items=device.getAllStacks()
  for n,slot in pairs(items) do item=slot.all()
    --item получает поля display_name,dmg,id,name,nbt_hash,ore_dict
		inventory=market.chest.setInventoryList(inventory,item,n)
	end
  
	return inventory
end

function market.me.get_inventoryitemlist()
	local me_inventory={}
	me_inventory.size=0
	local item=''
	local available=me.getItemsInNetwork()
	local loop=#available
	
	for n=1,loop do
		item=available[n]
		me_inventory=market.me.setInventoryList(me_inventory,item,n)
	end
	return me_inventory
end

function market.me.setInventoryList(me_inventory,item,n)
  local id=''
  --здесь item - это предмет из списка ме-сети
	if item and not me_inventory[item.name..'&&'..item.damage] then
		id=item.name..'&&'..item.damage
		me_inventory[id]={}
		me_inventory[id].display_name=item.label
    me_inventory[id].damage=item.damage
		me_inventory[id].sell_price='9999'
		me_inventory[id].buy_price='0'
		me_inventory[id].name=item.name
		me_inventory[id].qty=item.size
		me_inventory[id].slots={n}--индекс предмета в ме
		me_inventory.size=me_inventory.size+1
	else if item then
		--print('эта часть точно работает?')
		id=item.name..'&&'..item.damage
		--me_inventory[id].qty=me_inventory[id].qty+item.size
    me_inventory[id].qty=item.size
		me_inventory[id].slots[#me_inventory[id].slots+1]=n
		end
	end
	return me_inventory
end

function market.chest.setInventoryList(inventory,item,n)
  local id=''
	local dmg = tostring(math.floor(item.dmg))
	if item then id=item.id..'&&'..dmg end

  if not inventory[id] then
		id=item.id..'&&'..dmg
		inventory[id]={}
		inventory[id].display_name=item.display_name
    inventory[id].damage=dmg
		inventory[id].sell_price=item.sell_price
		inventory[id].buy_price=item.buy_price
		inventory[id].name=item.id
		inventory[id].qty=item.qty
		inventory[id].slots={n}--номера слотов занимаемых предметом
		inventory.size=inventory.size+1
	else if item then
		id=item.id..'&&'..dmg
		inventory[id].qty=inventory[id].qty+item.qty
		inventory[id].slots[#inventory[id].slots+1]=n
		end
	end
	return inventory
end

--load itemlist from file
function market.load_fromFile()
	--market.itemlist = {}
	if not fs.exists('home/db.market') then
		local db=io.open('db.market','w')
		db:write('0'..'\n')
    db:close()
	end
		local db=io.open('db.market','r')
		local size=db:read('*line')
		if tonumber(size) then
			market.itemlist.size=size
      local name,id,damage,display_name,sell_price,buy_price='','','','','',''
       
			for _=1, size do 
				name=tostring(db:read('*line'))
        display_name = tostring(db:read('*line'))
        damage = tonumber(db:read('*line'))
        sell_price=tonumber(db:read('*line'))
        buy_price=tonumber(db:read('*line'))
        id=name..'&&'..tostring(damage)
        
          market.itemlist[id]={
            display_name=display_name,
            name=name,
            damage=damage,
            sell_price=sell_price,
            buy_price=buy_price
          
          }
			end
		end
		db:close()
	return true--itemlist
end

--save itemlist to file
function market.save_toFile()
  local size=market.itemlist.size
  market.itemlist.size=nil
	local db=io.open('db.market','w')
	db:write(tostring(size)..'\n')

	for id in pairs(market.itemlist)do
		db:write(tostring(market.itemlist[id].name)..'\n')
		db:write(tostring(market.itemlist[id].display_name)..'\n')
    db:write(tostring(market.itemlist[id].damage)..'\n')
		db:write(tostring(market.itemlist[id].sell_price)..'\n')
		db:write(tostring(market.itemlist[id].buy_price)..'\n')
	end
  
	market.itemlist.size=size
	db:close()
	return true
end

--замена кнопок экрана: вызов очистки и прорисовки
function market.replace()
	market.clear()--(0x111111)
  
	return market.place(market.screen)
end

--Очистка экрана ничего особенного. Обычный велосипед
market.clear=function(background)
	--gpu.setActiveBuffer(zero)	
	if not background then background=0x111111 end
	local x,y=gpu.getViewport()
	gpu.setBackground(background)
	gpu.fill(1,1,x,y,' ')
	--gpu.setActiveBuffer(one)
	return true
end
--размещает текущие одноцветные кнопки на экране
market.place=function(buttons)
	--gpu.setActiveBuffer(zero)
	for n in pairs(buttons)do
		local b=market.button[buttons[n]]
		gpu.setBackground(b.bg)
		gpu.fill((b.x),(b.y),(b.xs),(b.ys),' ')
		gpu.setForeground(b.fg)
		gpu.set((b.x)+(b.tx),(b.y)+(b.ty),b.text)
	end
	--gpu.setActiveBuffer(one)
	return true
end

function market.screenInit()
	market.clear(0x202020)
	return market.place({'entrance','pim1','pim2'})
end

market.unlinked=function(address)
	market.serverAddress = address
	market.link = 'linked'
	local msg={name='pimmarket',op='getOwners',number=market.msgnum,value=0}
	return market.serverPost(msg)
end

market.linked=function() return 'server already linked' end

--получили serverResponse. Уточняем детали
market.serverResponse=function(e)

	local msg,address = e[6],e[3]
	--address - адрес отправителя
	msg=serialization.unserialize(msg) or ''
	--а нам ли сообщение?
	if msg == 'name' or not msg.sender then return true 
	end
	if msg.sender ~= modem.address then return true 
	end
		--msg.number,msg.name,msg.value
		--msg.op = {enter|buy|sell|balanceIn|balanceOut|
		--getOwners|transfer|isRegistered}
	modem.close(port)
	market.events.modem_message=nil
		--процедура регистрации терминала завершена. сохраняем адрес сервера
	if msg.op=='connect'  then 
		return market[market.link](address)
	end
	if not market.serverAddress==address then 
		return "undefined server. access blocked"
	end
	if msg.name and msg.name == market.player.name then 
		market.player.balance = msg.balance
		market.msgnum = market.msgnum + 1
	end
	--переход по коду совершённой операции
	return market.modem[msg.op](msg)
end

market.modem={}
function market.modem.getOwners(msg)
	market.owner=msg.owners
--[[
  local users = computer.users()
  if users
    then for _,user in pairs(users)do
      if user ~= market.owner[1].name then
        computer.removeUser(user) 
      end
    end
  end  
    for _,owner in pairs(market.owner)do
      computer.addUser(owner.name)
    end
  ]]
  function component.keyboard.isAltDown()return end--:trollface:
	market.events.player_on='pimWho'
	return market.screenInit()
end
--запрашиваемый игрок не найден
function market.modem.regFalse(_)
	return market.isRegistered(false)
end
--запрашиваемый игрок найден
function market.modem.regTrue(_)
	return market.isRegistered(true)
end
--завершение перевода средств
function market.modem.transfer(_)
	return market.transferComplite()
end
--завершение покупки
function market.modem.buy(_)
	return market.finalizeBuy()
end
function market.modem.sell(_)
	return market.finalizeSell()
end
function market.modem.balanceIn(_)

end
function market.modem.balanceOut(_)
	
end
--от сервера получен баланс игрока
function market.modem.enter(_)
	return market.eula()
end

function market.eula()
	market.clear()
	market.button.eula14.text='пишите '..market.owner[1].name
	market.place({'eula1','eula2','eula3','eula4','eula5','eula6','eula7','eula9','eula10','eula12','eula13','eula14'})
	market.screen={'eula11'}
	return market.place(market.screen)
end

--отправка сообщений на сервер
function market.serverPost(msg)
	msg=serialization.serialize(msg)
	modem.broadcast(send,msg)
	--включаем прослушивание порта и добавляем в список обрабатываемых эвентов
	modem.open(port)
	market.events.modem_message='serverResponse'
	return true
end

function market.serverAccess()
	market.msgnum=tonumber('0x'..string.sub(modem.address,1,6))
	local msg={name='pimmarket',op='connect',number=market.msgnum,value=0}
	return market.serverPost(msg)
end

--перехват ивентов. надстройка над ОС
function computer.pullSignal(...)
	local e={pullSignal(...)}
	for event in pairs(market.events)do 
		if event==e[1] then
			return market[market.events[event]](e)
		end
  end
	return table.unpack(e) 
end
function adaptive()
   gpu.setResolution(76,44)
	--gpu.allocateBuffer(1,1)
  return gpu.getResolution()
end
--инициализация
function market.init()
	--надо сперва чекать сундук, затем на его основе подтягивать поля с ценой из файла
	--либо наоборот. в любом случае сундук апдейдит лист в файле и сохраняет его
	sx,sy = adaptive()
	market.mode='trade'
	print('load database from file...')
	market.load_fromFile()
	print('file loading succesfull')
	print('getting chest inventory...')
  --поместим список предметов из МЕ-сети в chestList
	market.chestList=market[market.workmode].get_inventoryitemlist(market.chestShop)
  --chestList.size = число позиций в ме сети
	--теперь апдейт листа путем добавления полей с отсутствующими айди из сундука в итемлист
	--а market.inumList будет содержать указатели присутствующих товаров в itemList
	print('merge tables')
  --
	market.merge()
	--сортировка нумерного листа торговли в алфавитный порядок
	print('sorting available items...')
	market.sort()
	print('save current database...')
	--и сохранение нового листа на диск?. когда, если не сейчас?
	market.save_toFile(market.itemlist)
	print('initialization complete')
	print('waiting for server access..')
	market.events.touch=nil
	market.events.player_off=nil
	market.events.player_on=nil
	return market.serverAccess()
end

market.init()
while math.huge do os.sleep(0.01) end
return market