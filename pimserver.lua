--pimserver 1.1
local pimserver={}
pimserver.version='1.00'
local db={}
local owners={}
local event=require('event')
local modem=require('component').modem
local port = 0xfffe
local send = 0xffef
local fs = require('filesystem')
--local log={}
local serialization = require('serialization')
local terminal={}
local unregistered={}
local gpu = require('component').gpu
modem.open(port)
modem.setWakeMessage="{name="
local player_on = false
local computer=require('computer')
local pullSignal=computer.pullSignal	
computer.pullSignal=function(...)
	local e={pullSignal(...)}
	if e[1]=='modem_message' then
		return pimserver.modem(e)
	end
	if e[1]=='touch' then
		return pimserver.accept(e)
	end
	if e[1]=='player_on' then
		return pimserver.regOwner(e)
	end
	return table.unpack(e) 
end

function pimserver.modem(e) ---1type 2respondent 3sender 4port 5distance 6message
	local sender=e[3]
	os.sleep(0.05)
	--want to msg fields:
	--msg.number
	--msg.name =name of player
	--msg.op = enter|buy|sell|balanceIn|balanceOut
	--msg.value = value of operation
	local msg = serialization.unserialize(e[6])
  msg.sender = sender
  --регистрация терминалов
  if msg.name and msg.name=='pimmarket' then
  		return pimserver[msg.op](sender)
  end
  --проверка валидности адреса посылки
  local valid = false
  for n in pairs(terminal) do
  	if terminal[n]==sender then valid = true end
  end
	if not valid then return 'не знаем мы таких' end
	--если такого игрока нет, то запись нового игрока в бд
	if msg.name and not db[msg.name] then pimserver.newUser(msg.name) end
	--если в сообщении есть имя игрока отправляем по типу операции
	if msg.name then return pimserver[msg.op](msg) end
	--поиск отклика завершенных событий
	--if msg.complite==true then return true end
	--остальные события нас не интересуют
	return true
end

--постановка терминала в список ожидания регистрации
function pimserver.connect(sender)
	for n in pairs(terminal) do
		--если такой терминал есть в списке валидных
  	if terminal[n]==sender then
  		return pimserver.returnAccept(sender)
  	end
  end
	table.insert(unregistered,sender)
	return pimserver.place()
end
function pimserver.getOwners(sender)
	local msg={sender=sender,number=1,name='pimmarket',balance=0,op='getOwners'}
	msg.owners=owners
	pimserver.post(msg)
end
--отсылка подтверждения регистрации
function pimserver.accept(msg)
	local who = msg[6]
	for id in pairs(owners)do
		if owners[id].name == who then
			who = nil
		end
	end
	if who then return true end
	local x,y = msg[3],msg[4]
	--if msg[6]==adminname then
	if x < 4 and y == 1 then
		return pimserver.WaitToNewOwner()
	end
	if y < 13 then return true end
	y=y-12
	if x == 3 and y <= #unregistered then
		table.remove(unregistered,y)
	end
	if x == 43 and y <= #unregistered then
		local sender=table.remove(unregistered,y)
		table.insert(terminal, sender)
		pimserver.saveTerminalsToFile()
		return pimserver.returnAccept(sender)
	end
	--end
	return true
end

function pimserver.returnAccept(sender)
	local msg={sender=sender,number=1,name='pimmarket',balance=0,op='connect'}
	pimserver.post(msg)
	return pimserver.place()
	end

function pimserver.place()
	local x,y = gpu.getResolution()
	gpu.setBackground(0x113311)
	gpu.setForeground(0x58f029)
	gpu.fill(1,1,x,y,' ')
	gpu.set(1,1,'REG: step on PIM for register owner')
	gpu.set(5,1,'Registered terminals:')
	for t in pairs(terminal) do
		gpu.set(5,t+1,terminal[t])
	end
	gpu.set(5,12,'Unregistered terminals:')
	for t in pairs(unregistered) do
		gpu.set(5,t+12,unregistered[t])
		gpu.set(3,t+12,'X')
		gpu.set(43,t+12,'V')
	end
	return true
end
--первичная регистрация игрока
function pimserver.enter(msg)
	if not db[msg.name] then pimserver.newUser(msg.name)
		print('new user'..msg.name)
		msg.new='new'
	end
	return pimserver.broadcast(msg)
end
--проверка наличия имени в базе данных
function pimserver.isRegistered(msg)
	if not db[msg.name2] then 
		msg.op = 'regFalse'
	else
		msg.op = 'regTrue'
	end
	return pimserver.broadcast(msg)
end
--перевод со счета на счет
function pimserver.transfer(msg)
	if not db[msg.name2] then pimserver.newUser(msg.name2)
		print('new user'..msg.name2)
	end
	db[msg.name].balance=db[msg.name].balance - msg.value
	db[msg.name2].balance=db[msg.name2].balance + msg.value
	return pimserver.broadcast(msg)
end
--вычитание с баланса при покупке
function pimserver.buy(msg)
	db[msg.name].balance=db[msg.name].balance - msg.value
	return pimserver.broadcast(msg)
end
--различные операции вызываемые по ключу в сообщении
function pimserver.sell(msg)
	db[msg.name].balance=db[msg.name].balance + msg.value
	return pimserver.broadcast(msg)
end
function pimserver.balanceIn(msg)
	db[msg.name].balance=db[msg.name].balance + msg.value
	return pimserver.broadcast(msg)
end
function pimserver.balanceOut(msg)
	db[msg.name].balance=db[msg.name].balance - msg.value
	return pimserver.broadcast(msg)
end
--отправка результата с указанием адреса пославшего
function pimserver.broadcast(msg)
  local sender, balance, number, name, op = msg.sender, db[msg.name].balance, msg.number, msg.name, msg.op
	local post={sender=sender,number=number,name=name,balance=balance,op=op}
	if msg.new then post.new='new' end
	pimserver.post(post)	
	--[[if not log[msg.sender] then log[msg.sender]={} end
		log[msg.sender][msg.number]={name=msg.name,op=msg.op,val=msg.value}
	local line='['..serialization.serialize(msg.sender)..']'..'['..serialization.serialize(msg.number)..']'..serialization.serialize(log[msg.sender][msg.mnumber])
	local logs=io.open('logs.pimserver','w','a')
	logs:write(line)
	logs:close()]]--
	return pimserver.saveFile()
end
function pimserver.post(msg)
local post = serialization.serialize(msg)
	return modem.broadcast(send,post)
end

function pimserver.newUser(name)
	db[name]={}
	db[name].balance='0'
	db[name].ban='-'
	db[name].income='0'
	return pimserver.saveFile()
end
--создание овнер-листа посредством пим
function pimserver.WaitToNewOwner()
	if not owners[1] then
		print('Встаньте на ПИМ для регистрации первого владельца')
	else
		print('Встаньте на ПИМ для регистрации следующего владельца')
	end
	player_on = true
	return true
end
function pimserver.regOwner(a) 
	table.insert(owners,{UUID=a[3],name=a[2]})
	print('Благодарю. владелец '..#owners..' '..a[2]..'  UUID:'..a[3]..'  зарегестрирован')
	return pimserver.saveOwnersTable()
end
--сохранение терминалов в файл
function pimserver.saveTerminalsToFile()
	local dbs=io.open('terminals.pimserver','w')
	for n in pairs(terminal)do
		dbs:write(tostring(terminal[n])..'\n')
	end
	dbs:close()
	return true
end
--загрузка терминалов из файла
function pimserver.loadTerminalsFromFile()
	terminal={}
	local dbs=io.open('terminals.pimserver','r')
		local loop = true
		while loop do
			local line=dbs:read('*line')
			if line then
				table.insert(terminal,line)
			else
				loop = false
			end
		end
		
		dbs:close()
		return terminal
end

function pimserver.saveFile()
	local dbs=io.open('db.pimserver','w')
	for player in pairs(db)do
		dbs:write(tostring(player)..'\n')
		dbs:write(tostring(db[player].ban..'\n'))
		dbs:write(tostring(db[player].balance..'\n'))
		dbs:write(tostring(db[player].income..'\n'))
	end
	dbs:close()
	return true
end

function pimserver.loadFile()
	db={}
	local dbs=io.open('db.pimserver','r')
		local loop = true
		while loop do
			local line=dbs:read('*line')
			if not line then
				loop = false	
			else
				local name=tostring(line)
				db[name]={}
				db[name].ban=tostring(dbs:read('*line'))
				db[name].balance=tostring(dbs:read('*line'))
				db[name].income=tostring(dbs:read('*line'))
			end
		end
		dbs:close()
		return true
end

function pimserver.loadOwnersTable()
	local file=io.open('owners.pimserver')
	owners=serialization.unserialize(file:read('*a'))
	return true
end

function pimserver.saveOwnersTable()
	local file=io.open('owners.pimserver','w')
	local data=serialization.serialize(owners)
	file:write(data)
	file:close()
	return true
end

function pimserver.init()
	if not fs.exists ('home/db.pimserver') then
		pimserver.newUser('Taoshi')
		pimserver.saveFile()
	end
	pimserver.loadFile()
	if fs.exists('home/terminals.pimserver') then
		pimserver.loadTerminalsFromFile()
	end
	if fs.exists('home/owners.pimserver') then
		pimserver.loadOwnersTable()
	else
		pimserver.WaitToNewOwner()
	end
	pimserver.place()
	return true
end

function wakeUp()
	local msg = 'name'
  modem.broadcast(send,msg)
  return true
end

event.timer(15,wakeUp,math.huge)
gpu.setResolution(76,24)
pimserver.init()
print('Сервер поднят.')
return pimserver