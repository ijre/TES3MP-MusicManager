local Helpers =
{
  MusicTypes =
  {
    Stop = -1,
    OnDemand = 0,
    OnDemandDuringRadio = 1,
    Radio = 2,
    Loop = 3
  }
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
  beforeMsg = beforeMsg and beforeMsg or ""

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

  return randomTrack
end

function Helpers:GetSongLength(pid, fileName)
  local rawStr = io.popen(string.format([[%s\GetFileProps\GetFileProperties.exe "%s%s"]], MusicManager.Config.PathToSelfScripts, MusicManager.Config.PathToMusic, fileName)):read()
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

function Helpers:ShouldVerifyCache(cache)
  local count = 0
  local cacheSize = tableHelper.getCount(cache)

  for file in io.popen(string.format([[dir "%s" /b]], MusicManager.Config.PathToMusic)):lines() do
    local fileSplit = file:split(".")
    local name = fileSplit[1]
    local ext = fileSplit[2]

    local validExts =
    {
      "mp3",
      "wav",
      "mdi"
    }

    if not tableHelper.containsCaseInsensitiveString(validExts, ext) then
      goto continue end

    if not cache[name] then
      return true
    end

    count = count + 1

    ::continue::
  end

  if count ~= cacheSize then
    return true
  end

  return false
end

function Helpers:UpdateCache(pid)
  local ret = { }

  self:PrintToChat(pid, "Updating song cache, this may take a while!", false, true, "\n")

  for file in io.popen(string.format([[dir "%s" /b]], MusicManager.Config.PathToMusic)):lines() do
    local fileSplit = file:split(".")
    local name = fileSplit[1]
    local ext = fileSplit[2]

    local validExts =
    {
      "mp3",
      "wav",
      "mdi"
    }

    if not tableHelper.containsCaseInsensitiveString(validExts, ext) then
      goto continue end

    local splitCount = tableHelper.getCount(fileSplit)

    if splitCount ~= 2 then
      local err = ""

      if splitCount == 1 then
        err = "File name is missing an extension."
      elseif splitCount > 2 then
        err = "File name has more than one period, and no I cannot be fucked to reconstruct the entire goddamn array to fix the name do you have any idea how anno"
      end

      self:PrintToChat(pid, string.format("Error when caching \"%s\", reason: \"%s\"", file, err), true, true)
    else
      local leng = -1

      if not file:find("\'") then
        leng = self:GetSongLength(pid, file)
      else
        local newFile = string.gsub(file, "\'", "`")

        local function renameCMD(oldName, newName)
          return string.format([[move "%s%s" "%s%s"]], MusicManager.Config.PathToMusic, oldName, MusicManager.Config.PathToMusic, newName)
        end

        io.popen(renameCMD(file, newFile))

        leng = self:GetSongLength(pid, newFile)

        io.popen(renameCMD(newFile, file))
      end

      ret[name] =
      {
        Ext = ext,
        Length = leng
      }
    end

    ::continue::
  end

  return ret
end

function OnSongEnd(pid, song)
  if MusicManager.CurrentSongType == Helpers.MusicTypes.Stop then
    tes3mp.LogMessage(2, "[MusicManager]: \"OnSongEnd\" called but CurrentSongType was set to stop?")
    return
  end

  if MusicManager.CurrentSongType == Helpers.MusicTypes.Radio or MusicManager.CurrentSongType == Helpers.MusicTypes.OnDemandDuringRadio then
    MusicManager.RadioStart(pid)
  elseif MusicManager.CurrentSongType == Helpers.MusicTypes.Loop then
    Helpers:PrintToChat(pid, song, false, true)
    Helpers:PlayNewSong(pid, song, Helpers.MusicTypes.Loop)
  end
end

function Helpers:PlayNewSong(pid, song, playingType)
  MusicManager.CurrentSongType = playingType

  if playingType == self.MusicTypes.Stop then
    logicHandler.RunConsoleCommandOnPlayer(pid, "StreamMusic \"\"")
    return
  end

  local data = MusicManager.CachedFiles[song]

  if not data then
    if not song then
      song = ""
    end

    tes3mp.LogMessage(3, "[Music Manager]: \"PlayNewSong\" failed when trying to play " .. song)
    return
  end

  if not MusicManager.SongTimer then
    MusicManager.SongTimer = tes3mp.CreateTimerEx("OnSongEnd", data.Length, "is", pid, song)
    tes3mp.StartTimer(MusicManager.SongTimer)
  else
    tes3mp.RestartTimer(MusicManager.SongTimer, data.Length)
  end

  logicHandler.RunConsoleCommandOnPlayer(pid, string.format("StreamMusic \"%s%s.%s\"", MusicManager.Config.PathToMusicRelative, song, data.Ext))
end

return Helpers