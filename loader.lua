local loader='0.5.0'
local inet=require('internet')
local fs=require('filesystem')
local event=require('event')
local component=require('component')
local itemlist,inventory={},{}


for address in component.list("filesy") do 
        if component.proxy(address).spaceTotal() > 66000 then
            fs = component.proxy(address)
            --return true
        end
end
if not fs then
  customError("Filesystem not found!")
end

--download library
--if not fs.exists("market.lua") then
	local handle=inet.request('https://raw.githubusercontent.com/Zardar/pimmarket/master/loader.lua')
	local result=''
	for chunk in handle do result=result..chunk end
	local file=io.open('loader.lua','w')
	file:write(result)
	file:close()


	local handle=inet.request('https://raw.githubusercontent.com/Zardar/pimmarket/master/pimscaninventory.lua')
	local result=''
	for chunk in handle do result=result..chunk end
	local file=io.open('market.lua','w')
	file:write(result)
	file:close()
--end

local market=require'market'
--local itemlist=market.load_fromFile()


function builder(player,uuid,id)
	print(player,uuid,id)
	m=require('market')
	print(m)
	itemlist=m.load_fromFile({})
	inventory=m.get_playeritemlist({})
	m.price_build(inventory,itemlist)
	m.save_toFile(itemlist)
	print('waiting for player leave')
	event.pull('player_off')
end

event.listen('player_on',builder)
print('starting up')