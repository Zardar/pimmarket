--me=component.me_interface
--d=component.database


--allItems=me.getItemsInNetwork()
--stack=me.getItemDetail({id=allItems[3].name})
--stack.all()
--stack.basic()
--stack.select()

--allCraftables=me.getCraftables()
--status=allCraftables[index].request() -- заказ Крафта
--status.isDone() -- готов ли предмет
--allCraftables={}--создаёт список предметов доступных к крафту
--for v,f in pairs(me.getCraftables())do if type(f)=='table' then table.insert(allCraftables,f.getItemStack())end end
--crafts=allCraftables
--crafts.

--работа в рамках базы данных
--stack={}
--for n in pairs(db) do
	-- получаем данные о конкретном предмете 
--stack[n]=me.getItemDetail({id=db.get(n).name,raw_name=db.get(n).label}).basic()
--или table.insert(stack,me.getItemDetail({id=db.get(n).name,raw_name=db.get(n).label}).basic())
--amount=stack.basic().qty 
--count=1 or 64
--получаем предмет из сети
--size= me.exportItem({id=id,dmg=dmg,raw.name=raw_name},'up',count).size


print ('empty in this time')
return true

-- что собственно надо от ме
--составление списка предметов на основе данных database
--помещение предмета в ме
--изъятие предмета из ме
--выбор между ме и сундуком и сопутствующая переменная, меняющая вызов методов
--допустим market.workmode='me' или 'ch'
--и на основе этого вызовы методов 
--market[market.workmode].вызываемый метод
--функции market.me.getInventoryItemList
--market.me.fromInvToInv
--на вход подать используемый компонент: пим или сундук.
--[[db=require'component'.database
capacity = 0
--если вы захотите базу данных
function market.getCapacity()
  for _,v in pairs(computer.getDeviceInfo())do
    if v.description=='Object catalogue'
      then return tonumber(v.capacity) 
    end 
  end
  return 0
end
]]

function market.me.get_inventoryitemlist()
	for _,v in pairs(computer.getDeviceInfo())do if v.description='Memory bank' then size = v.capacity end end
	local inventory={}
	inventory.size=0
	local id,item='',''
	
	for f=1,size do
		item=me.getItemDetail({id=db.get(n).name,raw_name=db.get(n).label}).basic()
	 	--заполняет таблицу инвентаря,
	 	--добавляя поле slots для повторяющихся
	 	--в инвентаре предметов. суммирует qty для них
	 	--в поле id пишется raw_name
		if item and not inventory[item.raw_name] then
			id=item.raw_name
			inventory[id]={}
			inventory[id].display_name=item.display_name
			inventory[id].sell_price=9999
			inventory[id].buy_price=0
			inventory[id].name=item.name
			inventory[id].qty=item.qty
			inventory[id].slots={f}--номера слотов занимаемых предметом
			inventory.size=inventory.size+1
		else if item then
			id=item.raw_name
			inventory[id].qty=inventory[id].qty+item.qty
			inventory[id].slots[#inventory[id].slots+1]=f
			--table.insert(inventory[id].slots,f)--можно заменить на
			end
		end
	end
	return inventory
end
--!!!эта функция только выдаёт предметы!!!
function market.me.fromInvToInv(device,raw_name,count, op)
	local c=count
	item=market.me.getItemDetail(raw_name)

	local available=item.qty
	while c > 0 do
		if c > item.max_size then
			if c <= available then
				c=c-item.max_size
				size= me.exportItem({id=id,dmg=dmg,raw.name=raw_name},'up',item.max_size).size
			else
				size= me.exportItem({id=id,dmg=dmg,raw.name=raw_name},'up',c).size
				c=0
			end
		end
	end
	
	return true
end
function market.me.getItemDetail(raw_name)
	local size = market.getCapacity()
	for n=1,size do 
		if db.get(n) and raw_name == db.get(n).label then
			return me.getItemDetail({id=db.get(n).name,raw_name=db.get(n).label}).basic()
		end
	end
end
