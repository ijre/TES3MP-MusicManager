math.randomseed(os.time())

MusicManager =
{
  Config =
  {
    PathToMusic = nil
    -- REPLACE "PathToMusic" WITH AN ABSOLUTE PATH TO FOLDER CONTAINING YOUR MUSIC
      -- FOLDER MUST STILL BE LOCATED IN MORROWIND'S "Data Files/Music/"
  },
  CachedFiles = { }
}

local function SetupHelpers()
  local valid, ret = pcall(function()
    MusicManager.Config.PathToSelfScripts = "server\\scripts\\custom\\MusicManager"
    return require("custom/MusicManager/helpers")
  end)

  if not valid then
    MusicManager.Config.PathToSelfScripts = "server\\scripts\\custom\\MM\\MusicManager"
    ret = require("custom/MM/MusicManager/helpers")
    MusicManager.Config.PathToMusic = "C:\\Program Files (x86)\\Steam\\steamapps\\common\\Morrowind\\Data Files\\Music\\Custom"
  end

  MusicManager.Config.PathToSelfData = "server\\data\\custom"

  return ret
end

local Helpers = SetupHelpers()
MusicManager.Helpers = Helpers

function MusicManager:PopulateCache(pid)
  if self.Config.PathToMusic == nil then
    self.Helpers:PrintToChat(pid,
    "Script is configured incorrectly, and does not feature a path to the custom tracks where it should have one."
    .."\nFixing this will require editing the script file directly, as well as a server restart after.", true)

    return nil
  end

  if not tableHelper.isEmpty(self.CachedFiles) then
    -- Morrowind only loads in custom files once, so we should do the same to avoid perceived false negatives
      -- caused by songs showing up during `/listtracks` that won't play if added during a session
    return true
  end

  self.Config.PathToMusic = Helpers:FixSlashes(self.Config.PathToMusic)

  local _, relativePathInd = self.Config.PathToMusic:find("Data Files")
  self.Config["PathToMusicRelative"] = self.Config.PathToMusic:sub(relativePathInd + 8)
    -- 8 is length of "/Music/" plus 1 to bypass the last slash, using its length to avoid issues with searching for / versus \

  for file in io.popen(string.format([[dir "%s" /b]], self.Config.PathToMusic)):lines() do
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

      self.Helpers:PrintToChat(pid, string.format("Error when caching \"%s\", reason: \"%s\"", file, err), true, true)
    else
      local leng = -1

      if not file:find("\'") then
        leng = self.Helpers:GetSongLength(pid, file)
      else
        local newFile = string.gsub(file, "\'", "`")

        local function renameCMD(oldName, newName)
          return string.format([[move "%s%s" "%s%s"]], self.Config.PathToMusic, oldName, self.Config.PathToMusic, newName)
        end

        io.popen(renameCMD(file, newFile))

        leng = self.Helpers:GetSongLength(pid, newFile)

        io.popen(renameCMD(newFile, file))
      end

      self.CachedFiles[name] =
      {
        Ext = ext,
        Length = leng
      }
    end

    ::continue::
  end

  return true
end

function MusicManager.PlayTrack(pid, cmd)
  if not MusicManager:PopulateCache(pid) then
    return
  end

  local requestedTrack = tableHelper.concatenateFromIndex(cmd, 2)

  local name = Helpers:GetCaseInsensTableKey(MusicManager.CachedFiles, requestedTrack)

  if not name then
    Helpers:PrintToChat(pid, "Song not found.", true)
    return
  end

  local ext = MusicManager.CachedFiles[name].Ext

  logicHandler.RunConsoleCommandOnPlayer(pid, string.format("StreamMusic \"%s%s.%s\"", MusicManager.Config.PathToMusicRelative, name, ext))
end

function ContinueRadio(pid)
  local randTrack, randTrackData = Helpers:GetRandomTrack()

  MusicManager.PlayTrack(pid, { " ", randTrack })

  tes3mp.RestartTimer(MusicManager.RadioTimer, randTrackData.Length)
end

function MusicManager.RadioStart(pid, cmd)
  if not MusicManager:PopulateCache(pid) then
    return
  end

  local randTrack, randTrackData = Helpers:GetRandomTrack()

  MusicManager.PlayTrack(pid, { " ", randTrack })

  if MusicManager.RadioTimer then
    tes3mp.StopTimer(MusicManager.RadioTimer)
  end

  MusicManager.RadioTimer = tes3mp.CreateTimerEx("ContinueRadio", randTrackData.Length, "i", pid)
  tes3mp.StartTimer(MusicManager.RadioTimer)
end

function MusicManager.RadioStop(pid)
  if MusicManager.RadioTimer then
    tes3mp.StopTimer(MusicManager.RadioTimer)
    MusicManager.RadioTimer = nil
  end
end

function MusicManager.ListTracks(pid)
  if not MusicManager:PopulateCache(pid) then
    return
  end

  local sortedSongs = Helpers:GetSortedSongList()

  for _, key in ipairs(sortedSongs) do
    Helpers:PrintToChat(pid, key)
  end
end

function MusicManager.ReloadTracks(pid, cmd)
  MusicManager.CachedFiles = { }

  MusicManager:PopulateCache(pid)

  Helpers:PrintToChat(pid, string.format(
    "Tracks reloaded!\n%sPlease note: OpenMW only loads its data files between restarts; "
    .. "this command is only so that the server's list is up to date.", color.Warning), false, true, "\n")
end

local cmdList =
{
  "playtrack",
  "radiostart",
  "radiostop",
  "listtracks",
  "reloadtracks"
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
customCommandHooks.registerCommand("radiostart", MusicManager.RadioStart)
customCommandHooks.registerCommand("radiostop", MusicManager.RadioStop)
customCommandHooks.registerCommand("listtracks", MusicManager.ListTracks)
customCommandHooks.registerCommand("reloadtracks", MusicManager.ReloadTracks)