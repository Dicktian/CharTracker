-- CharTracker 1.3-3.3.5aa - WoW 3.3.5a
-- © Comunaxo
-- https://github.com/Dicktian
-- All information is saved locally; log in on each character to refresh it.
local addon = CreateFrame('Frame')
local db, me, window, minimapButton
local rows = {}
local page = 1
local selectedKey = nil
local pageNames = {'Personajes', 'Oro y oficios', 'Profesiones', 'Emblemas', 'PvP', 'Raids', 'Notas'}
local pageIcons = {'Interface\\Icons\\INV_Misc_GroupLooking','Interface\\Icons\\INV_Misc_Coin_01','Interface\\Icons\\Trade_BlackSmithing','Interface\\Icons\\INV_Misc_Coin_17','Interface\\Icons\\INV_Sword_04','Interface\\Icons\\INV_Misc_Key_04','Interface\\Icons\\INV_Misc_Note_01'}
local visibleRows, rowHeight = 9, 29
local scrollOffset = 0
local currency = {
 {49426,'Escarcha'}, {47241,'Triunfo'}, {47242,'Conquista'},
 {40753,'Valor'}, {40752,'Heroísmo'},
 {43016,'Premio cocina'}, {41596,'Muestra joyero'}
}
local currencyAliases = {
 [49426]={'Emblem of Frost','Emblema de Escarcha'},
 [47241]={'Emblem of Triumph','Emblema de Triunfo'},
 [47242]={'Emblem of Conquest','Emblema de Conquista'},
 [40753]={'Emblem of Valor','Emblema de Valor'},
 [40752]={'Emblem of Heroism','Emblema de Heroísmo','Emblema de Heroismo'},
 [43016]={'Dalaran Cooking Award','Premio de cocina de Dalaran'},
 [41596]={'Dalaran Jewelcrafter\'s Token','Muestra de joyero de Dalaran'},
}
local professions = {
 ['Alquimia']=true, ['Alchemy']=true, ['Herrería']=true, ['Blacksmithing']=true,
 ['Encantamiento']=true, ['Enchanting']=true, ['Ingeniería']=true, ['Engineering']=true,
 ['Herboristería']=true, ['Herbalism']=true, ['Inscripción']=true, ['Inscription']=true,
 ['Joyería']=true, ['Jewelcrafting']=true, ['Peletería']=true, ['Leatherworking']=true,
 ['Minería']=true, ['Mining']=true, ['Desuello']=true, ['Skinning']=true,
 ['Sastrería']=true, ['Tailoring']=true, ['Cocina']=true, ['Cooking']=true,
 ['Pesca']=true, ['Fishing']=true, ['Primeros auxilios']=true, ['First Aid']=true
}
local raidNames = {
 {'VOA', {'Vault of Archavon','Cámara de Archavon','Camara de Archavon'}},
 {'TOC', {'Trial of the Crusader','Prueba del Cruzado','Coliseo de los Cruzados','Trial of the Grand Crusader'}},
 {'ICC', {'Icecrown Citadel','Ciudadela de la Corona de Hielo'}},
 {'RS', {'The Ruby Sanctum','Santuario Rubí','Santuario Rubi'}}
}
local function safeNumber(f, ...)
 if type(f)~='function' then return 0 end
 local ok, v=pcall(f, ...)
 if ok and type(v)=='number' then return v end
 return 0
end
local function currentKey()
 return (GetRealmName() or '?')..' - '..(UnitName('player') or '?')
end
local function ensureDB()
 if type(CharTrackerDB)~='table' then CharTrackerDB={} end
 db=CharTrackerDB
 if type(db.characters)~='table' then db.characters={} end
 if type(db.minimapAngle)~='number' then db.minimapAngle=225 end
 if type(db.globalDKP)~='number' then db.globalDKP=0 end
 if type(db.globalNotes)~='string' then db.globalNotes='' end
 if type(db.notesBoard1)~='string' then db.notesBoard1=db.globalNotes end
 if type(db.notesBoard2)~='string' then db.notesBoard2='' end
 -- Copy existing EmblemTracker snapshots without overwriting current CharTracker data.
 if type(EmblemTrackerDB)=='table' and type(EmblemTrackerDB.characters)=='table' and not db.migrated then
  for key, old in pairs(EmblemTrackerDB.characters) do
   if not db.characters[key] then
    local record={name=old.name, realm=old.realm, counts={}, raids={}}
    for id, count in pairs(old.counts or {}) do record.counts[id]=count end
    db.characters[key]=record
   end
  end
  db.migrated=true
 end
end
local function record()
 if not me then return nil end
 local r=db.characters[me]
 if not r then r={counts={},raids={}} db.characters[me]=r end
 r.counts=r.counts or {}
 r.raids=r.raids or {}
 return r
end
local function updateEquipment()
 local r=record()
 if not r then return end
 local sum, count=0,0
 for slot=1,17 do
  if slot~=4 and slot~=18 then
   local link=GetInventoryItemLink('player',slot)
   if link and type(GetItemInfo)=='function' then
    local _,_,_,level=GetItemInfo(link)
    if type(level)=='number' and level>0 then sum=sum+level;count=count+1 end
   end
  end
 end
 if count>0 then r.itemLevel=math.floor(sum/count+0.5) end
end
local function updateRiding()
 local r=record()
 if not r or type(GetNumSkillLines)~='function' then return end
 for i=1,GetNumSkillLines() do
  local name,header,_,rank=GetSkillLineInfo(i)
  if not header and name and (name=='Riding' or name=='Equitación' or name=='Equitacion') then
   r.riding=rank or 0
   return
  end
 end
end
local classNames={WARRIOR='Guerrero',PALADIN='Paladín',HUNTER='Cazador',ROGUE='Pícaro',PRIEST='Sacerdote',DEATHKNIGHT='Caballero de la Muerte',SHAMAN='Chamán',MAGE='Mago',WARLOCK='Brujo',DRUID='Druida'}
local function coloredCharacterName(r, name)
 local c=RAID_CLASS_COLORS and RAID_CLASS_COLORS[r.class or '']
 if c then return string.format('|cff%02x%02x%02x%s|r',math.floor(c.r*255),math.floor(c.g*255),math.floor(c.b*255),name) end
 return name
end
local function classText(r)
 local class=r.class or ''
 local name=classNames[class] or class
 local c=RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
 if c then return string.format('|cff%02x%02x%02x%s|r',math.floor(c.r*255),math.floor(c.g*255),math.floor(c.b*255),name) end
 return name
end
local function updateBasic()
 local r=record()
 if not r then return end
 r.name=UnitName('player') or '?'
 r.realm=GetRealmName() or '?'
 r.level=UnitLevel('player') or 0
 r.class=select(2, UnitClass('player')) or '?'
 -- Guild information may not be ready during PLAYER_LOGIN in 3.3.5a.
 -- Never erase a previously detected guild just because the API is temporarily nil.
 if type(GetGuildInfo)=='function' then
  local guildName=GetGuildInfo('player')
  if type(guildName)=='string' and guildName~='' then
   r.guild=guildName
  elseif type(IsInGuild)=='function' and IsInGuild()==false then
   r.guild=''
  end
 end
 if type(GetMoney)=='function' then r.gold=safeNumber(GetMoney) end
 r.updated=date('%Y-%m-%d %H:%M')
 if type(GetPVPLifetimeStats)=='function' then
  local ok,kills=pcall(GetPVPLifetimeStats)
  if ok and type(kills)=='number' then r.totalKills=kills end
 end
 updateEquipment();updateRiding()
 local currencyByName = {}
 if type(GetCurrencyListSize)=='function' and type(GetCurrencyListInfo)=='function' then
  local ok, size=pcall(GetCurrencyListSize)
  if ok and type(size)=='number' then
   for index=1,size do
    local success, name, isHeader, isExpanded, isUnused, isWatched, count = pcall(GetCurrencyListInfo,index)
    if success and name and not isHeader and type(count)=='number' then
     currencyByName[string.lower(name)]=count
    end
   end
  end
 end
 for _, c in ipairs(currency) do
  local amount
  if type(GetCurrencyInfo)=='function' then
   local ok, name, count=pcall(GetCurrencyInfo,c[1])
   if ok and type(count)=='number' then amount=count end
  end
  if amount==nil then
   local aliases=currencyAliases[c[1]] or {}
   for _, alias in ipairs(aliases) do
    local value=currencyByName[string.lower(alias)]
    if type(value)=='number' then amount=value;break end
   end
  end
  if amount==nil and type(GetItemCount)=='function' then
   local ok, value=pcall(GetItemCount,c[1],true)
   if ok and type(value)=='number' and value>0 then amount=value end
  end
  -- Do not erase previously saved currency data when an API is unavailable.
  if amount~=nil then r.counts[c[1]]=amount end
 end
 if type(GetHonorCurrency)=='function' then r.honor=safeNumber(GetHonorCurrency) end
 if type(GetArenaCurrency)=='function' then r.arena=safeNumber(GetArenaCurrency) end
end
local function updateProfessions()
 local r=record()
 if not r then return end
 local found={}
 if type(GetNumSkillLines)=='function' and type(GetSkillLineInfo)=='function' then
  for i=1,GetNumSkillLines() do
   local name, isHeader, _, rank, _, _, maxRank=GetSkillLineInfo(i)
   if name and not isHeader and professions[name] then
    table.insert(found, {name=name,rank=rank or 0,max=maxRank or 0})
   end
  end
 end
 if #found>0 then r.professions=found end
 updateRiding()
end
local function raidType(difficulty)
 local types={[1]='10N',[2]='25N',[3]='10H',[4]='25H'}
 return types[tonumber(difficulty) or 0]
end
local function raidCode(instanceName)
 if type(instanceName)~='string' then return nil end
 local lower=string.lower(instanceName)
 for _, raid in ipairs(raidNames) do
  for _, name in ipairs(raid[2]) do
   if string.find(lower,string.lower(name),1,true) then return raid[1] end
  end
 end
end
local function updateRaids()
 local r=record()
 if not r or type(GetNumSavedInstances)~='function' then return end
 -- Only report active lockouts. An expired or missing lockout is not a visit history.
 local locks={}
 for i=1,GetNumSavedInstances() do
  local name, id, reset, difficulty, locked, extended, instanceIDMostSig, isRaid, maxPlayers, difficultyName, numEncounters, encounterProgress = GetSavedInstanceInfo(i)
  local raid=raidCode(name)
  local kind=raidType(difficulty)
  if raid and kind and (locked or extended) and (reset or 0)>0 then
   locks[raid..'_'..kind]={reset=reset or 0, progress=encounterProgress, bosses=numEncounters, name=name}
  end
 end
 r.raids=locks
 r.raidsUpdated=date('%Y-%m-%d %H:%M')
end
local function sorted()
 local out={}
 for key,r in pairs(db.characters) do table.insert(out,{key=key,r=r}) end
 local order={}
 for i,key in ipairs(db.order or {}) do order[key]=i end
 table.sort(out,function(a,b)
  local ai,bi=order[a.key],order[b.key]
  if ai and bi then return ai<bi end
  if ai then return true end
  if bi then return false end
  local x=(a.r.name or a.key):lower();local y=(b.r.name or b.key):lower()
  if x==y then return a.key<b.key end
  return x<y
 end)
 return out
end
local function placeCharacter(sourceKey,targetKey)
 if not sourceKey or not targetKey or sourceKey==targetKey then return end
 local chars=sorted()
 local sourceIndex,targetIndex
 for i,item in ipairs(chars) do
  if item.key==sourceKey then sourceIndex=i end
  if item.key==targetKey then targetIndex=i end
 end
 if not sourceIndex or not targetIndex then return end
 local moved=table.remove(chars,sourceIndex)
 table.insert(chars,targetIndex,moved)
 db.order={}
 for i,item in ipairs(chars) do db.order[i]=item.key end
end
local function txt(parent, size, color)
 local t=parent:CreateFontString(nil,'OVERLAY',size or 'GameFontHighlightSmall')
 t:SetJustifyH('LEFT')
 if color then t:SetTextColor(unpack(color)) end
 return t
end
local function niceMoney(copper)
 local g=math.floor((copper or 0)/10000)
 local s=math.floor(((copper or 0)%10000)/100)
 local c=(copper or 0)%100
 return string.format('|cffffd100%d oro|r  |cffc7c7cf%02d plata|r  |cffc77b3b%02d cobre|r',g,s,c)
end
local function hours(seconds)
 if type(seconds)~='number' then return '—' end
 return string.format('%dd %dh',math.floor(seconds/86400),math.floor(seconds%86400/3600))
end
local function profText(r)
 local p={}
 for _, v in ipairs(r.professions or {}) do
  table.insert(p, (v.name or '?')..' '..(v.rank or 0))
 end
 if #p==0 then return '—' end
 return table.concat(p,', ')
end
-- Colores visuales por rango de aprendizaje; WoW no asigna colores oficiales a estos rangos.
local function professionColor(rank)
 rank=tonumber(rank) or 0
 if rank>=375 then return 'ffb784e8' -- Gran maestro
 elseif rank>=300 then return 'ff78c6e8' -- Maestro
 elseif rank>=225 then return 'ff77c7a0' -- Artesano
 elseif rank>=150 then return 'ffe0c67d' -- Experto
 elseif rank>=75 then return 'ffd6a17d' -- Oficial
 else return 'ffb8b8b8' end -- Aprendiz
end
local function coloredProfession(p)
 local rank=tonumber(p.rank) or 0
 local text=(p.name or '?')..' '..rank..'/'..tostring(p.max or 450)
 return '|c'..professionColor(rank)..text..'|r'
end
local function professionCells(r)
 local main,secondary={},{}
 for _,p in ipairs(r.professions or {}) do
  local n=(p.name or ''):lower()
  local v=coloredProfession(p)
  if n=='cooking' or n=='cocina' then secondary[1]=v
  elseif n=='fishing' or n=='pesca' then secondary[2]=v
  elseif n=='first aid' or n=='primeros auxilios' then secondary[3]=v
  else table.insert(main,v) end
 end
 return {main[1] or '',main[2] or '',secondary[1] or '',secondary[2] or '',secondary[3] or ''}
end
local function getColumns()
 if page==7 then return {}, {} end
 if page==1 then
  return {'PERSONAJE','CLASE','NIVEL','EQUIPO iLVL','TIEMPO','GUILD'}, {185,195,85,155,155,310}
 elseif page==3 then
  return {'PERSONAJE','PROFESIÓN 1','PROFESIÓN 2','COCINA','PESCA','PRIMEROS AUX.','MONTURA'}, {175,180,180,135,130,160,145}
 elseif page==2 then
  return {'PERSONAJE','COCINA','JOYERO','ORO','PLATA','COBRE'}, {185,130,130,160,145,145}
 elseif page==4 then
  return {'PERSONAJE','ESCARCHA','TRIUNFO','CONQUISTA','VALOR','HEROÍSMO'}, {190,130,130,130,120,130}
 elseif page==5 then
  return {'PERSONAJE','HONOR','ARENA','MUERTES TOTALES'}, {240,200,200,250}
 else
  return {'PERSONAJE','ICC 10','ICC 25','VOA 10','VOA 25','RS 10','RS 25','TOC 10','TOC 25','TOGC 10','TOGC 25'}, {180,87,87,87,87,87,87,90,90,90,90}
 end
end
local function getRaidCell(r,raid,diff)
 local locks=r.raids or {}
 if raid~='TOC' then
  local size=string.sub(diff,1,2)
  return (locks[raid..'_'..size..'N'] or locks[raid..'_'..size..'H']) and '+' or ''
 end
 return locks[raid..'_'..diff] and '+' or ''
end
local function makeEntries()
 local entries={}
 if page==7 then return entries end
 for _,item in ipairs(sorted()) do
  local r=item.r;local name=coloredCharacterName(r,r.name or item.key)
  if page==1 then
   table.insert(entries,{name,classText(r),tostring(r.level or ''),r.itemLevel and tostring(r.itemLevel) or '—',hours(r.played),r.guild or ''})
  elseif page==3 then
   local line={name}
   for _,v in ipairs(professionCells(r)) do table.insert(line,v) end
   local riding=tonumber(r.riding)
   table.insert(line,riding and ('|c'..professionColor(riding)..tostring(riding)..'|r') or '—')
   table.insert(entries,line)
  elseif page==2 then
   local copper=math.floor(tonumber(r.gold) or 0)
   table.insert(entries,{name,tostring((r.counts or {})[43016] or 0),tostring((r.counts or {})[41596] or 0),'|cffffd100'..math.floor(copper/10000)..'|r','|cffc7c7cf'..string.format('%02d',math.floor(copper%10000/100))..'|r','|cffc77b3b'..string.format('%02d',copper%100)..'|r'})
  elseif page==4 then
   local line={name}
   for i=1,5 do table.insert(line,tostring((r.counts or {})[currency[i][1]] or 0)) end
   table.insert(entries,line)
  elseif page==5 then
   table.insert(entries,{name,tostring(r.honor or 0),tostring(r.arena or 0),r.totalKills and tostring(r.totalKills) or '—'})
  else
   local line={name}
   for _,pair in ipairs({{'ICC','10N'},{'ICC','25N'},{'VOA','10N'},{'VOA','25N'},{'RS','10N'},{'RS','25N'},{'TOC','10N'},{'TOC','25N'},{'TOC','10H'},{'TOC','25H'}}) do
    table.insert(line,getRaidCell(r,pair[1],pair[2]))
   end
   table.insert(entries,line)
  end
 end
 return entries
end
local function updateUI()
 if not window or not window:IsShown() then return end
 if page==7 then window.notesPanel:Show() else window.notesPanel:Hide() end
 if page==7 then window.tableBack:Hide() else window.tableBack:Show() end
 if page==7 then window.headerBand:Hide() else window.headerBand:Show() end
 if page==7 then window.slider:Hide() else window.slider:Show() end
 local cols,widths=getColumns()
 local n=#cols
 local left=24
 local tableWidth=window.tableWidth
 local totalWidth=0
 for _,w in ipairs(widths) do totalWidth=totalWidth+w end
 local positions={}; local x=left
 for j=1,n do positions[j]=x;x=x+widths[j] end
 for j=1,13 do
  local h=window.headers[j]
  h:SetText(cols[j] or '')
  h:SetWidth((widths[j] or 1)-12)
  h:ClearAllPoints()
  h:SetPoint('TOPLEFT',window,'TOPLEFT',(positions[j] or left)+6,-134)
  h:SetJustifyH('CENTER')
 end
 local count=0
 for _ in pairs(db.characters or {}) do count=count+1 end
 window.registeredLabel:SetText(tostring(count)..'/18 registrados')
 local entries=makeEntries()
 local maxOffset=math.max(0,#entries-visibleRows)
 scrollOffset=math.max(0,math.min(scrollOffset,maxOffset))
 window.slider:SetMinMaxValues(0,maxOffset)
 if window.slider:GetValue()~=scrollOffset then window.slider:SetValue(scrollOffset) end
 for i=1,visibleRows do
  local values=entries[i+scrollOffset]
  if values then window.rowBands[i]:Show() else window.rowBands[i]:Hide() end
  if window.rowBands[i] then
   if window.rowKeys and selectedKey and (sorted()[i+scrollOffset] and sorted()[i+scrollOffset].key)==selectedKey then
    window.rowBands[i]:SetVertexColor(0.30,0.30,0.34,1)
   elseif i%2==0 then window.rowBands[i]:SetVertexColor(0.16,0.16,0.18,0.95)
   else window.rowBands[i]:SetVertexColor(0.11,0.11,0.13,0.90) end
  end
  local entry=sorted()[i+scrollOffset]
  local key=entry and entry.key
  window.rowKeys[i]=key
  if window.rowHitboxes then
   if key and page~=7 and page~=8 then window.rowHitboxes[i]:Show() else window.rowHitboxes[i]:Hide() end
  end
  for j=1,13 do
   local cell=rows[i][j]
   cell:SetWidth((widths[j] or 1)-12-0)
   cell:ClearAllPoints()
   cell:SetPoint('TOPLEFT',window,'TOPLEFT',(positions[j] or left)+6+0,-172-(i-1)*rowHeight)
   cell:SetJustifyH('CENTER')
   cell:SetText(values and (values[j] or '') or '')
   if j==1 then cell:SetTextColor(1,1,1)
   elseif page==6 and values and values[j]=='+' then cell:SetTextColor(0.35,0.92,0.60)
   else cell:SetTextColor(0.88,0.88,0.90) end
  end
 end
 -- The redundant character/row counter is intentionally removed.
 local total={}
 if page==1 then total={'Selecciona una fila y luego su destino para reordenar; también puedes arrastrarla. DKP compartido se guarda automáticamente.'}
 elseif page==3 then total={'Profesiones: nivel actual / máximo'}
 elseif page==2 then
  local a,b,g=0,0,0
  for _,r in pairs(db.characters) do a=a+((r.counts or {})[43016] or 0);b=b+((r.counts or {})[41596] or 0);g=g+(r.gold or 0) end
  total={'Cocina: '..a,'Joyero: '..b,'Dinero: '..niceMoney(g)}
 elseif page==4 then
  for i=1,5 do
   local sum=0
   for _,r in pairs(db.characters) do sum=sum+((r.counts or {})[currency[i][1]] or 0) end
   table.insert(total,currency[i][2]..': '..sum)
  end
 elseif page==5 then
  local a,b=0,0
  for _,r in pairs(db.characters) do a=a+(r.honor or 0);b=b+(r.arena or 0) end
  total={'Honor: '..a,'Arena: '..b}
 elseif page==6 then total={'Raids: + = ID activo | vacío = sin ID | TOGC = heroico'}
 elseif page==7 then total={'Notas compartidas entre todos los personajes; se guardan al escribir.'}
 else total={} end
 window.total:SetText(table.concat(total,'     |     '))
 for i,button in ipairs(window.tabs) do
  if i==page then
   button.label:SetTextColor(0.95,0.97,1)
   button.bg:SetVertexColor(0.30,0.30,0.33,1)
  else
   button.label:SetTextColor(0.72,0.79,0.87)
   button.bg:SetVertexColor(0.15,0.15,0.17,1)
  end
 end
end
StaticPopupDialogs['CHARTRACKER_RESET_ALL']={
 text='¿Borrar TODOS los registros, notas, orden y DKP de esta cuenta? No se puede deshacer. Tras recargar se registrará el personaje conectado.',
 button1='Borrar todo',button2='Cancelar',timeout=0,whileDead=true,hideOnEscape=true,
 OnAccept=function()
  if not db then ensureDB() end
  db.characters={};db.order={};db.globalDKP=0;db.globalNotes='';db.notesBoard1='';db.notesBoard2='';db.migrated=true
  -- Clear any other legacy per-character ordering fields.
  db.characterOrder=nil
  ReloadUI() -- saves cleared data, then PLAYER_LOGIN registers only current character
 end,
}
local function createUI()
 if window then return end
 window=CreateFrame('Frame','CharTrackerWindow',UIParent)
 window:SetWidth(1190);window:SetHeight(555)
 window:SetPoint('CENTER');window:SetFrameStrata('DIALOG')
 window:SetMovable(true);window:EnableMouse(true)
 window:RegisterForDrag('LeftButton')
 window:SetScript('OnDragStart',function(self) self:StartMoving() end)
 window:SetScript('OnDragStop',function(self) self:StopMovingOrSizing() end)
 window:SetBackdrop({bgFile='Interface\\Buttons\\WHITE8X8',edgeFile='Interface\\Tooltips\\UI-Tooltip-Border',tile=false,edgeSize=12,insets={left=3,right=3,top=3,bottom=3}})
 window:SetBackdropColor(0.065,0.065,0.075,0.98)
 window:SetBackdropBorderColor(0.28,0.28,0.31,1)
 window:Hide()
 table.insert(UISpecialFrames,'CharTrackerWindow')
 local title=txt(window,'GameFontNormalLarge')
 title:SetPoint('TOPLEFT',window,'TOPLEFT',24,-18)
 title:SetText('|cffedf3fbCharTracker|r  |cffaaaaaav1.3-3.3.5aa|r')
 local subtitle=txt(window,'GameFontDisableSmall')
 subtitle:SetPoint('TOPLEFT',window,'TOPLEFT',24,-42)
 subtitle:SetText('Resumen de personajes  •  WoW 3.3.5a')
 local registered=txt(window,'GameFontNormalSmall')
 registered:SetPoint('TOPRIGHT',window,'TOPRIGHT',-370,-43)
 registered:SetTextColor(0.78,0.78,0.78)
 window.registeredLabel=registered
 local close=CreateFrame('Button',nil,window,'UIPanelCloseButton')
 close:SetPoint('TOPRIGHT',window,'TOPRIGHT',-7,-7)
 -- DKP is a single shared value across all characters and all tabs.
 local dkpLabel=txt(window,'GameFontNormalSmall')
 dkpLabel:SetPoint('TOPRIGHT',window,'TOPRIGHT',-235,-22)
 dkpLabel:SetText('DKP GLOBAL')
 local dkpEdit=CreateFrame('EditBox',nil,window)
 dkpEdit:SetWidth(105);dkpEdit:SetHeight(24)
 -- Cuadro plano, rectangular y monocromatico (sin bordes redondeados de InputBoxTemplate).
 dkpEdit:SetBackdrop({bgFile='Interface\\Buttons\\WHITE8X8',edgeFile='Interface\\Buttons\\WHITE8X8',edgeSize=1,insets={left=1,right=1,top=1,bottom=1}})
 dkpEdit:SetBackdropColor(0.16,0.16,0.16,1)
 dkpEdit:SetBackdropBorderColor(0.48,0.48,0.48,1)
 dkpEdit:SetFontObject('GameFontHighlightSmall')
 dkpEdit:SetTextColor(0.92,0.92,0.92)
 dkpEdit:SetJustifyH('CENTER')
 dkpEdit:SetTextInsets(6,6,0,0)
 dkpEdit:SetPoint('LEFT',dkpLabel,'RIGHT',14,0)
 dkpEdit:SetAutoFocus(false)
 dkpEdit:SetNumeric(true)
 dkpEdit:SetMaxLetters(9)
 dkpEdit:SetText(tostring(db.globalDKP or 0))
 dkpEdit:SetScript('OnTextChanged',function(self)
  if not db then return end
  local value=tonumber(self:GetText())
  if value then db.globalDKP=value end
 end)
 dkpEdit:SetScript('OnEnterPressed',function(self) self:ClearFocus() end)
 dkpEdit:SetScript('OnEscapePressed',function(self) self:ClearFocus() end)
 window.globalDKPEdit=dkpEdit
 window.tabs={}
 local tx=22
 for i,name in ipairs(pageNames) do
  local button=CreateFrame('Button',nil,window)
  button:SetWidth(135);button:SetHeight(39)
  button:SetPoint('TOPLEFT',window,'TOPLEFT',tx,-73)
  local bg=button:CreateTexture(nil,'BACKGROUND');bg:SetAllPoints(button)
  bg:SetTexture('Interface\\Buttons\\WHITE8X8');button.bg=bg
  local icon=button:CreateTexture(nil,'ARTWORK')
  icon:SetWidth(19);icon:SetHeight(19)
  icon:SetPoint('LEFT',button,'LEFT',10,0)
  icon:SetTexture(pageIcons[i])
  local label=txt(button,'GameFontNormalSmall')
  label:SetPoint('LEFT',button,'LEFT',35,0)
  label:SetWidth(99);label:SetJustifyH('LEFT');label:SetText(name)
  button.label=label
  button:SetScript('OnClick',function() page=i;scrollOffset=0;updateUI() end)
  window.tabs[i]=button
  tx=tx+143
 end
 local tableBack=window:CreateTexture(nil,'BACKGROUND')
 tableBack:SetTexture('Interface\\Buttons\\WHITE8X8')
 tableBack:SetVertexColor(0.095,0.095,0.105,1)
 tableBack:SetPoint('TOPLEFT',window,'TOPLEFT',18,-122)
 tableBack:SetPoint('BOTTOMRIGHT',window,'BOTTOMRIGHT',-40,108)
 window.tableBack=tableBack
 local headerBand=window:CreateTexture(nil,'ARTWORK')
 headerBand:SetTexture('Interface\\Buttons\\WHITE8X8')
 headerBand:SetVertexColor(0.22,0.22,0.24,1)
 headerBand:SetPoint('TOPLEFT',window,'TOPLEFT',20,-125)
 headerBand:SetWidth(1124);headerBand:SetHeight(39)
 window.headerBand=headerBand
 window.headers={}
 for j=1,13 do
  local h=txt(window,'GameFontNormalSmall')
  h:SetHeight(30)
  window.headers[j]=h
 end
 window.rowBands={}
 for i=1,visibleRows do
  local band=window:CreateTexture(nil,'ARTWORK')
  band:SetTexture('Interface\\Buttons\\WHITE8X8')
  if i%2==0 then band:SetVertexColor(0.16,0.16,0.18,0.95)
  else band:SetVertexColor(0.11,0.11,0.13,0.90) end
  band:SetPoint('TOPLEFT',window,'TOPLEFT',20,-167-(i-1)*rowHeight)
  band:SetWidth(1124);band:SetHeight(rowHeight-2)
  window.rowBands[i]=band
  rows[i]={}
  window.rowKeys=window.rowKeys or {}
  window.rowHitboxes=window.rowHitboxes or {}
  local hit=CreateFrame('Button',nil,window)
  hit:SetPoint('TOPLEFT',window,'TOPLEFT',20,-167-(i-1)*rowHeight)
  hit:SetWidth(1124);hit:SetHeight(rowHeight-2)
  hit:RegisterForDrag('LeftButton')
  hit:SetScript('OnClick',function()
   local target=window.rowKeys[i]
   if not target then return end
   if selectedKey and selectedKey~=target then placeCharacter(selectedKey,target);selectedKey=nil
   else selectedKey=(selectedKey==target) and nil or target end
   updateUI()
  end)
  hit:SetScript('OnDragStart',function() selectedKey=window.rowKeys[i];updateUI() end)
  hit:SetScript('OnDragStop',function()
   if not selectedKey then return end
   local cx,cy=GetCursorPosition()
   cy=cy/UIParent:GetEffectiveScale()
   for k,other in ipairs(window.rowHitboxes) do
    if other:IsShown() and cy<=other:GetTop() and cy>=other:GetBottom() then
     placeCharacter(selectedKey,window.rowKeys[k]);break
    end
   end
   selectedKey=nil;updateUI()
  end)
  window.rowHitboxes[i]=hit
  for j=1,13 do
   local t=txt(window,'GameFontHighlightSmall')
   t:SetHeight(rowHeight-4)
   rows[i][j]=t
  end
 end
 local slider=CreateFrame('Slider','CharTrackerScrollBar',window,'UIPanelScrollBarTemplate')
 slider:SetPoint('TOPRIGHT',window,'TOPRIGHT',-24,-182)
 slider:SetPoint('BOTTOMRIGHT',window,'BOTTOMRIGHT',-24,132)
 slider:SetWidth(16);slider:SetMinMaxValues(0,0);slider:SetValueStep(1)
 slider:SetScript('OnValueChanged',function(self,value)
  local n=math.floor(value+0.5)
  if n~=scrollOffset then scrollOffset=n;updateUI() end
 end)
 window.slider=slider
 -- Reemplazar las flechas de Blizzard por botones cuadrados monocromáticos.
 local function grayArrow(button, symbol)
  if not button then return end
  for _,region in ipairs({button:GetRegions()}) do
   if region and region.GetObjectType and region:GetObjectType()=='Texture' then region:SetAlpha(0) end
  end
  button:SetNormalTexture('');button:SetPushedTexture('');button:SetHighlightTexture('');button:SetDisabledTexture('')
  local bg=button:CreateTexture(nil,'BACKGROUND')
  bg:SetAllPoints(button);bg:SetTexture('Interface\\Buttons\\WHITE8X8');bg:SetVertexColor(0.24,0.24,0.24,1)
  local glyph=button:CreateFontString(nil,'OVERLAY','GameFontNormalSmall')
  glyph:SetAllPoints(button);glyph:SetText(symbol);glyph:SetTextColor(0.83,0.83,0.83)
  button:SetScript('OnEnter',function() bg:SetVertexColor(0.36,0.36,0.36,1) end)
  button:SetScript('OnLeave',function() bg:SetVertexColor(0.24,0.24,0.24,1) end)
 end
 grayArrow(_G['CharTrackerScrollBarScrollUpButton'],'▲')
 grayArrow(_G['CharTrackerScrollBarScrollDownButton'],'▼')
 local thumb=slider:GetThumbTexture()
 if thumb then thumb:SetTexture('Interface\\Buttons\\WHITE8X8');thumb:SetVertexColor(0.45,0.45,0.45,1);thumb:SetWidth(13);thumb:SetHeight(28) end
 -- Dos pizarras de notas independientes, sin barras de desplazamiento.
 local notesPanel=CreateFrame('Frame',nil,window)
 notesPanel:SetPoint('TOPLEFT',window,'TOPLEFT',24,-132)
 notesPanel:SetWidth(1110);notesPanel:SetHeight(305)
 local function makeBoard(x,field,title)
  local board=CreateFrame('Frame',nil,notesPanel)
  board:SetPoint('TOPLEFT',notesPanel,'TOPLEFT',x,0)
  board:SetWidth(540);board:SetHeight(305)
  local bg=board:CreateTexture(nil,'BACKGROUND')
  bg:SetAllPoints(board);bg:SetTexture('Interface\\Buttons\\WHITE8X8')
  bg:SetVertexColor(0.13,0.13,0.13,1)
  local heading=board:CreateFontString(nil,'OVERLAY','GameFontNormal')
  heading:SetPoint('TOPLEFT',board,'TOPLEFT',14,-12)
  heading:SetText(title);heading:SetTextColor(0.85,0.85,0.85)
  local counter=board:CreateFontString(nil,'OVERLAY','GameFontHighlightSmall')
  counter:SetPoint('TOPRIGHT',board,'TOPRIGHT',-14,-14)
  counter:SetJustifyH('RIGHT')
  counter:SetTextColor(0.66,0.66,0.66,1)
  local edit=CreateFrame('EditBox',nil,board)
  edit:SetPoint('TOPLEFT',board,'TOPLEFT',14,-40)
  edit:SetWidth(510);edit:SetHeight(250)
  edit:SetMultiLine(true);edit:SetAutoFocus(false)
  edit:SetFontObject('GameFontHighlight')
  edit:SetTextInsets(2,2,3,3)
  edit:SetMaxLetters(1200)
  edit:SetText(db[field] or '')
  edit:SetScript('OnTextChanged',function(self)
   local value=self:GetText() or ''
   if db then db[field]=value end
   counter:SetText(tostring(string.len(value))..'/1200')
  end)
  counter:SetText(tostring(string.len(edit:GetText() or ''))..'/1200')
  edit:SetScript('OnEscapePressed',function(self) self:ClearFocus() end)
  board:EnableMouse(true)
  board:SetScript('OnMouseDown',function() edit:SetFocus() end)
  return edit
 end
 window.notesBoard1=makeBoard(0,'notesBoard1','Pizarra 1')
 window.notesBoard2=makeBoard(558,'notesBoard2','Pizarra 2')
 notesPanel:Hide()
 window.notesPanel=notesPanel
 window:EnableMouseWheel(true)
 window:SetScript('OnMouseWheel',function(self,delta) self.slider:SetValue(math.max(0,scrollOffset-delta)) end)
 local footer=window:CreateTexture(nil,'BACKGROUND')
 footer:SetTexture('Interface\\Buttons\\WHITE8X8')
 footer:SetVertexColor(0.14,0.14,0.16,1)
 footer:SetPoint('BOTTOMLEFT',window,'BOTTOMLEFT',18,63)
 footer:SetPoint('BOTTOMRIGHT',window,'BOTTOMRIGHT',-18,63)
 footer:SetHeight(36)
 window.total=txt(window,'GameFontNormalSmall')
 window.total:SetPoint('BOTTOMLEFT',window,'BOTTOMLEFT',26,75)
 window.total:SetWidth(1120)
 local refresh=CreateFrame('Button',nil,window)
 refresh:SetWidth(108);refresh:SetHeight(26)
 refresh:SetPoint('BOTTOMRIGHT',window,'BOTTOMRIGHT',-20,37)
 -- Boton rectangular sin texturas redondeadas del tema Blizzard.
 local refreshBG=refresh:CreateTexture(nil,'BACKGROUND')
 refreshBG:SetTexture('Interface\\Buttons\\WHITE8X8')
 refreshBG:SetVertexColor(0.23,0.23,0.23,1)
 local refreshBorder=refresh:CreateTexture(nil,'BACKGROUND')
 refreshBorder:SetPoint('TOPLEFT',refresh,'TOPLEFT',0,0)
 refreshBorder:SetPoint('BOTTOMRIGHT',refresh,'BOTTOMRIGHT',0,0)
 refreshBorder:SetTexture('Interface\\Buttons\\WHITE8X8')
 refreshBorder:SetVertexColor(0.45,0.45,0.45,1)
 refreshBG:SetPoint('TOPLEFT',refreshBorder,'TOPLEFT',1,-1)
 refreshBG:SetPoint('BOTTOMRIGHT',refreshBorder,'BOTTOMRIGHT',-1,1)
 local refreshLabel=refresh:CreateFontString(nil,'OVERLAY','GameFontNormalSmall')
 refreshLabel:SetAllPoints(refresh)
 refreshLabel:SetJustifyH('CENTER')
 refreshLabel:SetJustifyV('MIDDLE')
 refreshLabel:SetTextColor(0.92,0.92,0.92,1)
 refreshLabel:SetText('Sincronizar')
 refresh:SetScript('OnEnter',function() refreshBG:SetVertexColor(0.34,0.34,0.34,1) end)
 refresh:SetScript('OnLeave',function() refreshBG:SetVertexColor(0.23,0.23,0.23,1) end)
 local reset=CreateFrame('Button',nil,window)
 reset:SetWidth(118);reset:SetHeight(26)
 reset:SetPoint('RIGHT',refresh,'LEFT',-10,0)
 local resetBG=reset:CreateTexture(nil,'BACKGROUND')
 resetBG:SetAllPoints(reset);resetBG:SetTexture('Interface\\Buttons\\WHITE8X8')
 resetBG:SetVertexColor(0.26,0.26,0.26,1)
 local resetLabel=reset:CreateFontString(nil,'OVERLAY','GameFontNormalSmall')
 resetLabel:SetAllPoints(reset);resetLabel:SetText('Borrar todo')
 resetLabel:SetTextColor(0.92,0.92,0.92,1)
 reset:SetScript('OnEnter',function() resetBG:SetVertexColor(0.37,0.37,0.37,1) end)
 reset:SetScript('OnLeave',function() resetBG:SetVertexColor(0.26,0.26,0.26,1) end)
 reset:SetScript('OnClick',function() StaticPopup_Show('CHARTRACKER_RESET_ALL') end)
 -- Guía liviana: se crea una sola vez y no usa EditBox ni ScrollFrame.
 local helpButton=CreateFrame('Button',nil,window)
 helpButton:SetWidth(84);helpButton:SetHeight(26)
 helpButton:SetPoint('RIGHT',reset,'LEFT',-10,0)
 local helpButtonBG=helpButton:CreateTexture(nil,'BACKGROUND')
 helpButtonBG:SetAllPoints(helpButton)
 helpButtonBG:SetTexture('Interface\\Buttons\\WHITE8X8')
 helpButtonBG:SetVertexColor(0.25,0.25,0.25,1)
 local helpButtonText=helpButton:CreateFontString(nil,'OVERLAY','GameFontNormalSmall')
 helpButtonText:SetAllPoints(helpButton);helpButtonText:SetText('Guía')
 helpButtonText:SetTextColor(0.92,0.92,0.92)
 local guide=CreateFrame('Frame','CharTrackerGuideWindow',UIParent)
 guide:SetWidth(760);guide:SetHeight(435);guide:SetPoint('CENTER')
 guide:SetFrameStrata('FULLSCREEN_DIALOG')
 guide:SetBackdrop({bgFile='Interface\\Buttons\\WHITE8X8',edgeFile='Interface\\Buttons\\WHITE8X8',edgeSize=1,insets={left=1,right=1,top=1,bottom=1}})
 guide:SetBackdropColor(0.11,0.11,0.11,0.98)
 guide:SetBackdropBorderColor(0.48,0.48,0.48,1)
 guide:EnableMouse(true);guide:Hide()
 table.insert(UISpecialFrames,'CharTrackerGuideWindow')
 local guideTitle=guide:CreateFontString(nil,'OVERLAY','GameFontNormalLarge')
 guideTitle:SetPoint('TOPLEFT',guide,'TOPLEFT',18,-16)
 guideTitle:SetText('CharTracker | Guía rápida')
 local leftText=guide:CreateFontString(nil,'OVERLAY','GameFontHighlightSmall')
 leftText:SetPoint('TOPLEFT',guide,'TOPLEFT',18,-52)
 leftText:SetWidth(346);leftText:SetJustifyH('LEFT');leftText:SetJustifyV('TOP')
 leftText:SetText([==[PERSONAJES: nivel, clase, guild, equipo. Haz clic en una fila y luego en otra para reordenar todas las tablas.

ORO Y OFICIOS: oro, plata, cobre, premios de cocina y joyería.

PROFESIONES: dos principales, Cocina, Pesca, Primeros Auxilios y Equitación.

EMBLEMAS: Escarcha, Triunfo, Conquista, Valor y Heroísmo.

PVP: honor, arena y muertes honorables acumuladas.

RAIDS: + significa bloqueo activo. TOC normal; TOGC heroico. No es historial.

NOTAS: texto compartido por personajes de esta cuenta.

DKP: valor único compartido dentro de la cuenta.]==])
 local rightText=guide:CreateFontString(nil,'OVERLAY','GameFontHighlightSmall')
 rightText:SetPoint('TOPLEFT',guide,'TOPLEFT',389,-52)
 rightText:SetWidth(346);rightText:SetJustifyH('LEFT');rightText:SetJustifyV('TOP')
 rightText:SetText([==[COLORES DE PROFESIONES (convención del addon):
Aprendiz 1-74: gris
Oficial 75-149: marrón claro
Experto 150-224: dorado
Artesano 225-299: verde
Maestro 300-374: azul
Gran maestro 375-450: violeta
Equitación utiliza la misma escala. Los nombres de personajes usan colores de clase oficiales.

SINCRONIZAR: actualiza el personaje conectado. /ct abre o cierra; /ctsave actualiza; /ctguild diagnostica guild.

REGISTRO: entra una vez con cada personaje. Las cuentas WoW tienen datos separados.

BORRAR TODO: requiere confirmación, elimina datos de esta cuenta y vuelve a registrar el personaje actual.

GUARDADO: WoW escribe los datos al salir o recargar interfaz.

© Comunaxo]==])
 local close=CreateFrame('Button',nil,guide)
 close:SetWidth(84);close:SetHeight(26)
 close:SetPoint('TOPRIGHT',guide,'TOPRIGHT',-14,-12)
 local closeBG=close:CreateTexture(nil,'BACKGROUND')
 closeBG:SetAllPoints(close);closeBG:SetTexture('Interface\\Buttons\\WHITE8X8')
 closeBG:SetVertexColor(0.27,0.27,0.27,1)
 local closeText=close:CreateFontString(nil,'OVERLAY','GameFontNormalSmall')
 closeText:SetAllPoints(close);closeText:SetText('Cerrar')
 close:SetScript('OnClick',function() guide:Hide() end)
 helpButton:SetScript('OnClick',function() if guide:IsShown() then guide:Hide() else guide:Show() end end)

 local copyright=txt(window,'GameFontDisableSmall')
 copyright:SetPoint('BOTTOMLEFT',window,'BOTTOMLEFT',26,16)
 copyright:SetText('© Comunaxo')
 local github=CreateFrame('Button',nil,window)
 github:SetWidth(180);github:SetHeight(20)
 github:SetPoint('BOTTOMRIGHT',window,'BOTTOMRIGHT',-20,10)
 local githubText=txt(github,'GameFontNormalSmall')
 githubText:SetAllPoints(github);githubText:SetJustifyH('RIGHT')
 githubText:SetText('|cff66b9ffgithub.com/Dicktian|r')
 github:SetScript('OnClick',function()
  if not window.linkPopup then
   local popup=CreateFrame('EditBox',nil,window,'InputBoxTemplate')
   popup:SetWidth(265);popup:SetHeight(22)
   popup:SetPoint('BOTTOM',window,'BOTTOM',0,34)
   popup:SetAutoFocus(false)
   popup:SetScript('OnEscapePressed',function(self) self:Hide() end)
   popup:SetScript('OnEnterPressed',function(self) self:HighlightText() end)
   window.linkPopup=popup
  end
  window.linkPopup:SetText('https://github.com/Dicktian')
  window.linkPopup:Show();window.linkPopup:SetFocus();window.linkPopup:HighlightText()
 end)
 refresh:SetScript('OnClick',function()
  if not me then ensureDB();me=currentKey() end
  updateBasic();updateProfessions()
  if type(RequestRaidInfo)=='function' then RequestRaidInfo() end
  if type(RequestTimePlayed)=='function' then RequestTimePlayed() end
  print('|cff70d7acCharTracker:|r sincronizado '..(UnitName('player') or '?'))
  updateUI()
 end)
end
local function toggleUI()
 if not db then ensureDB() end
 if not me then me=currentKey();updateBasic();updateProfessions() end
 createUI()
 if window:IsShown() then window:Hide() else window:Show();updateUI() end
end
local function positionMinimap()
 if not minimapButton then return end
 local rad=math.rad(db.minimapAngle or 225)
 minimapButton:ClearAllPoints()
 minimapButton:SetPoint('CENTER',Minimap,'CENTER',math.cos(rad)*80,math.sin(rad)*80)
end
local function createMinimap()
 if minimapButton then return end
 minimapButton=CreateFrame('Button','CharTrackerMinimapButton',Minimap)
 minimapButton:SetWidth(32);minimapButton:SetHeight(32)
 minimapButton:SetFrameStrata('MEDIUM')
 minimapButton:SetFrameLevel(Minimap:GetFrameLevel()+8)
 minimapButton:RegisterForClicks('LeftButtonUp')
 minimapButton:RegisterForDrag('LeftButton')
 local icon=minimapButton:CreateTexture(nil,'BACKGROUND')
 icon:SetPoint('CENTER');icon:SetWidth(20);icon:SetHeight(20)
 icon:SetTexture('Interface\\AddOns\\CharTracker\\Textures\\BloodElfIcon')
 local border=minimapButton:CreateTexture(nil,'OVERLAY')
 border:SetPoint('CENTER');border:SetWidth(54);border:SetHeight(54)
 border:SetTexture('Interface\\Minimap\\MiniMap-TrackingBorder')
 minimapButton:SetHighlightTexture('Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight')
 minimapButton:SetScript('OnClick',toggleUI)
 minimapButton:SetScript('OnEnter',function(self)
  GameTooltip:SetOwner(self,'ANCHOR_LEFT')
  GameTooltip:AddLine('CharTracker',1,0.8,0)
  GameTooltip:AddLine('Clic: abrir/cerrar | Arrastrar: mover',1,1,1)
  GameTooltip:Show()
 end)
 minimapButton:SetScript('OnLeave',function() GameTooltip:Hide() end)
 minimapButton:SetScript('OnDragStart',function(self)
  self:SetScript('OnUpdate',function()
   local mx,my=Minimap:GetCenter()
   local x,y=GetCursorPosition()
   local scale=UIParent:GetEffectiveScale()
   x=x/scale;y=y/scale
   local dx,dy=x-mx,y-my
   -- atan2 exists in the WoW Lua runtime as atan2.
   if type(atan2)=='function' then
    db.minimapAngle=math.deg(atan2(dy,dx))
   else
    db.minimapAngle=math.deg(math.atan(dy,dx))
   end
   positionMinimap()
  end)
 end)
 minimapButton:SetScript('OnDragStop',function(self) self:SetScript('OnUpdate',nil) end)
 positionMinimap()
end
-- Retry after login: on some 3.3.5a clients guild data arrives asynchronously.
local guildRetryElapsed=0
local guildRetryRemaining=0
local function refreshGuild()
 if not me then return false end
 local r=record()
 if not r then return false end
 local name=type(GetGuildInfo)=='function' and GetGuildInfo('player') or nil
 if type(name)=='string' and name~='' then
  local changed=r.guild~=name
  r.guild=name
  if changed and window and window:IsShown() then updateUI() end
  return true
 end
 if type(IsInGuild)=='function' and IsInGuild()==false then
  if r.guild~='' then r.guild=''; if window and window:IsShown() then updateUI() end end
  return true
 end
 return false
end
local function requestGuildRefresh()
 guildRetryElapsed=0
 guildRetryRemaining=30
 if type(GuildRoster)=='function' and (type(IsInGuild)~='function' or IsInGuild()) then
  pcall(GuildRoster)
 end
 refreshGuild()
end
addon:SetScript('OnUpdate',function(self,elapsed)
 if guildRetryRemaining<=0 then return end
 guildRetryRemaining=guildRetryRemaining-elapsed
 guildRetryElapsed=guildRetryElapsed+elapsed
 if guildRetryElapsed>=2 then
  guildRetryElapsed=0
  if refreshGuild() then guildRetryRemaining=0
  elseif type(GuildRoster)=='function' and (type(IsInGuild)~='function' or IsInGuild()) then pcall(GuildRoster) end
 end
end)
addon:RegisterEvent('PLAYER_LOGIN')
addon:RegisterEvent('PLAYER_ENTERING_WORLD')
addon:RegisterEvent('BAG_UPDATE')
addon:RegisterEvent('PLAYER_MONEY')
addon:RegisterEvent('HONOR_CURRENCY_UPDATE')
addon:RegisterEvent('CURRENCY_DISPLAY_UPDATE')
addon:RegisterEvent('SKILL_LINES_CHANGED')
addon:RegisterEvent('TIME_PLAYED_MSG')
addon:RegisterEvent('UPDATE_INSTANCE_INFO')
addon:RegisterEvent('PLAYER_LEVEL_UP')
addon:RegisterEvent('PLAYER_EQUIPMENT_CHANGED')
addon:RegisterEvent('PLAYER_GUILD_UPDATE')
addon:RegisterEvent('GUILD_ROSTER_UPDATE')
addon:SetScript('OnEvent',function(self,event,...)
 if event=='PLAYER_LOGIN' then
  ensureDB();me=currentKey();updateBasic();updateProfessions();requestGuildRefresh()
  print('|cff55dd99CharTracker v1.3-3.3.5aa:|r datos de '..(UnitName('player') or '?')..' registrados.')
  createMinimap()
  if type(RequestTimePlayed)=='function' then RequestTimePlayed() end
  if type(RequestRaidInfo)=='function' then RequestRaidInfo() end
 elseif me then
  if event=='TIME_PLAYED_MSG' then
   local total=...
   if type(total)=='number' then record().played=total end
  elseif event=='UPDATE_INSTANCE_INFO' then updateRaids()
  elseif event=='SKILL_LINES_CHANGED' then updateProfessions()
  elseif event=='PLAYER_GUILD_UPDATE' or event=='GUILD_ROSTER_UPDATE' then
   refreshGuild()
   if event=='PLAYER_GUILD_UPDATE' then requestGuildRefresh() end
  elseif event=='PLAYER_ENTERING_WORLD' then
   updateBasic();updateProfessions();requestGuildRefresh()
   if type(RequestRaidInfo)=='function' then RequestRaidInfo() end
  else updateBasic() end
  updateUI()
 end
end)
SLASH_CHARTRACKERSAVE1='/ctsave'
SlashCmdList.CHARTRACKERSAVE=function()
 if not me then print('|cffff5555CharTracker:|r todavía no está listo.') return end
 updateBasic();updateProfessions();requestGuildRefresh()
 if type(RequestRaidInfo)=='function' then RequestRaidInfo() end
 if type(RequestTimePlayed)=='function' then RequestTimePlayed() end
 print('|cff55dd99CharTracker:|r datos actualizados para '..(UnitName('player') or '?')..'.')
 updateUI()
end
SLASH_CHARTRACKER1='/chartracker'
SLASH_CHARTRACKER2='/ct'
SLASH_CHARTRACKER3='/emblems'
SlashCmdList.CHARTRACKER=toggleUI

SLASH_CHARTRACKERDEBUG1='/ctdebug'
SlashCmdList.CHARTRACKERDEBUG=function()
 if not db then ensureDB() end
 if not me then me=currentKey() end
 updateBasic();updateProfessions()
 local count=0
 for _ in pairs(db.characters or {}) do count=count+1 end
 print('|cff70d7acCharTracker:|r '..count..' personajes en la base de datos. Actual: '..tostring(me))
 print('Archivo de guardado: WTF/Account/<CUENTA>/SavedVariables/CharTracker.lua')
end

-- Diagnóstico de guild para comprobar la API del cliente y el valor mostrado.
SLASH_CHARTRACKERGUILD1='/ctguild'
SlashCmdList.CHARTRACKERGUILD=function()
 if not db then ensureDB() end
 if not me then me=currentKey() end
 local apiName=type(GetGuildInfo)=='function' and GetGuildInfo('player') or nil
 local inGuild=type(IsInGuild)=='function' and tostring(IsInGuild()) or 'API no disponible'
 refreshGuild()
 local r=record()
 print('|cffaaaaaaCharTracker Guild:|r API='..tostring(apiName)..' | IsInGuild='..inGuild..' | Guardada='..tostring(r and r.guild))
 if window and window:IsShown() then updateUI() end
end
