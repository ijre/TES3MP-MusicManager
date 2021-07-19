MusicManager =
{
  Config =
  {
    PathToMusic = nil
    -- REPLACE "PathToMusic" WITH AN ABSOLUTE PATH TO FOLDER CONTAINING YOUR MUSIC, MUST CONTAIN TRAILING SLASH
      -- FOLDER MUST STILL BE LOCATED IN MORROWIND'S "Data Files/Music/"
  },
  CachedFiles = { }
}

local function GetCaseInsensTableKey(tbl, strToFind)
  for key in pairs(tbl) do
    local keyStr = tostring(key)

    if keyStr:lower() == strToFind:lower() then
      return keyStr
    end
  end

  return nil
end

local function PrintToChat(pid, msg, isErr, toAll)
  local colour = isErr and color.Red or ""
  tes3mp.SendMessage(pid, string.format("%s[MusicManager]: %s\n", colour, msg), toAll)
end

function MusicManager:PopulateCache(pid)
  if self.Config.PathToMusic == nil then
    PrintToChat(pid,
    "Script is configured incorrectly, and does not feature a path to the custom tracks where it should have one."
    .."\nFixing this will require editing the script file directly, as well as a server restart after.", true)

    return nil
  end

  if not tableHelper.isEmpty(self.CachedFiles) then
    -- Morrowind only loads in custom files once, so we should do the same to avoid perceived false negatives
      -- caused by songs showing up during `/listtracks` that won't play if added during a session
    return true
  end

  for file in io.popen(string.format([[dir "%s" /b]], self.Config.PathToMusic)):lines() do
    local fileSplit = file:split(".")
    local name = fileSplit[1]
    local ext = fileSplit[2]

    local splitCount = tableHelper.getCount(fileSplit)

    if splitCount ~= 2 then
      local err = ""

      if splitCount == 1 then
        err = "File name is missing an extension."
      elseif splitCount > 2 then
        err = "File name has more than one period, and no I cannot be fucked to reconstruct the entire goddamn array to fix the name do you have any idea how anno"
      end

      PrintToChat(pid, string.format("Error when caching \"%s\", reason: \"%s\"", file, err), true, true)
    else
      self.CachedFiles[name] = { Ext = ext }
    end
  end

  local _, relativePathInd = self.Config.PathToMusic:find("Data Files")
  self.Config["PathToMusicRelative"] = self.Config.PathToMusic:sub(relativePathInd + 8)
    -- 8 is length of "/Music/" plus 1 to bypass the last slash, using its length to avoid issues with searching for / versus \

  return true
end

function MusicManager.PlayTrack(pid, cmd)
  if not MusicManager:PopulateCache(pid) then
    return
  end

  local requestedTrack = tableHelper.concatenateFromIndex(cmd, 2)

  local name = GetCaseInsensTableKey(MusicManager.CachedFiles, requestedTrack)

  if not name then
    PrintToChat(pid, "Song not found.", true)
    return
  end

  local ext = MusicManager.CachedFiles[name].Ext

  logicHandler.RunConsoleCommandOnPlayer(pid, string.format("StreamMusic \"%s%s.%s\"", MusicManager.Config.PathToMusicRelative, name, ext))
end

function MusicManager.ListTracks(pid)
  if not MusicManager:PopulateCache(pid) then
    return
  end

  for key in pairs(MusicManager.CachedFiles) do
    PrintToChat(pid, tostring(key))
  end
end

local cmdList =
{
  "playtracks",
  "listtracks"
}

local origProcess = commandHandler.ProcessCommand
function commandHandler.ProcessCommand(pid, cmd)
  if tableHelper.containsCaseInsensitiveString(cmdList, cmd[1]) then
    local newCmd = cmd
    newCmd[1] = newCmd[1]:lower()

    customCommandHooks.getCallback(newCmd[1]:lower())(pid, newCmd)

    return customEventHooks.makeEventStatus(false, nil)
  end

  return origProcess(pid, cmd)
end

customCommandHooks.registerCommand("playtrack", MusicManager.PlayTrack)
customCommandHooks.registerCommand("listtracks", MusicManager.ListTracks)