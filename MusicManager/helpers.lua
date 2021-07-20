local Helpers =
{
  PathToSelf = "server\\scripts\\custom\\MusicManager"
  -- PathToSelf = "server\\scripts\\custom\\MM\\MusicManager"
}

function Helpers:GetCaseInsensTableKey(tbl, strToFind)
  for key in pairs(tbl) do
    local keyStr = tostring(key)

    if keyStr:lower() == strToFind:lower() then
      return keyStr
    end
  end

  return nil
end

function Helpers:PrintToChat(pid, msg, isErr, toAll, beforeMsg)
  local colour = isErr and color.Red or color.GreenText
  beforeMsg = beforeMsg and true or ""

  tes3mp.SendMessage(pid, string.format("%s%s[MusicManager]: %s\n", beforeMsg, colour, msg), toAll)
end

function Helpers:FixSlashes(str)
  local newSlashes = string.gsub(str, "/", "\\")
  local lastSlash = string.find(newSlashes, "\\", -1)

  if not lastSlash then
    newSlashes = newSlashes .. "\\"
  end

  return newSlashes
end

function Helpers:GetSortedSongList()
  local keyList = { }

  for key in pairs(MusicManager.CachedFiles) do
    table.insert(keyList, key)
  end

  table.sort(keyList)

  return keyList
end

function Helpers:GetRandomTrack()
  local songList = self:GetSortedSongList()
  local randomTrack = songList[math.random(#songList)]
  local randomTrackData = MusicManager.CachedFiles[randomTrack]

  return randomTrack, randomTrackData
end

function Helpers:GetSongLength(pid, fileName)
  local rawStr = io.popen(string.format([[%s\GetFileProps\GetFileProperties.exe "%s%s"]], self.PathToSelf, MusicManager.Config.PathToMusic, fileName)):read()
  -- format is HH:MM:SS

  local timeSplit = rawStr:split(":")
    -- aw dude timesplitters i love that game

  if tableHelper.getCount(timeSplit) ~= 3 then
    self:PrintToChat(pid, string.format("Malformed duration string from track \"%s\", got \"%s\"", fileName, rawStr), true, true)
    return 0
  end

  local convertedHours   = tonumber(timeSplit[1]) * 3.6e+6
  local convertedMinutes = tonumber(timeSplit[2]) * 60000
  local convertedSeconds = tonumber(timeSplit[3]) * 1000

  return convertedHours + convertedMinutes + convertedSeconds
end

return Helpers