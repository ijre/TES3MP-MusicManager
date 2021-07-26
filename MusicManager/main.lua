math.randomseed(os.time())

MusicManager =
{
  Config =
  {
    PathToMusic = nil
    -- REPLACE "PathToMusic" WITH AN ABSOLUTE PATH TO FOLDER CONTAINING YOUR MUSIC
      -- FOLDER MUST STILL BE LOCATED IN MORROWIND'S "Data Files/Music/"
  },
  CachedFiles = { },
  TrackQueue = { }
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
MusicManager.CurrentSongType = Helpers.MusicTypes.Stop

function MusicManager:PopulateCache(pid, forceUpdate)
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

  local jsonPath = "custom/MusicManager_Cache.json"

  local cache = jsonInterface.load(jsonPath)

  if cache then
    forceUpdate = type(forceUpdate) == "boolean" and forceUpdate or self.Helpers:ShouldVerifyCache(cache)
  end

  if forceUpdate or not cache then
    cache = self.Helpers:UpdateCache(pid)
    jsonInterface.quicksave(jsonPath, cache)
  end

  self.CachedFiles = cache

  return true
end

function MusicManager.PlayTrack(pid, cmd)
  if not MusicManager:PopulateCache(pid) then
    return
  end

  local type = Helpers.MusicTypes.OnDemand

  if MusicManager.CurrentSongType == Helpers.MusicTypes.Radio then
    type = Helpers.MusicTypes.OnDemandDuringRadio
  end

  local name = Helpers:GetSongOnDemand(pid, cmd)

  if name then
    Helpers:PlayNewSong(pid, name, type)
  end
end

function MusicManager.RadioStart(pid)
  if not MusicManager:PopulateCache(pid) then
    return
  end

  local randTrack = Helpers:GetRandomTrack()

  Helpers:PlayNewSong(pid, randTrack, Helpers.MusicTypes.Radio)
end

function MusicManager.RadioStop(pid)
  Helpers:PlayNewSong(pid, _, Helpers.MusicTypes.Stop)

  tes3mp.StopTimer(MusicManager.SongTimer)
  MusicManager.SongTimer = nil

  Helpers:PrintToChat(pid, "Radio stopped.", true, true)
end

function MusicManager.ResumeQueue(pid)
  if not MusicManager:PopulateCache(pid) then
    return
  end

  if tableHelper.isEmpty(MusicManager.TrackQueue) then
    return
  end

  Helpers:PlayNewSong(pid, MusicManager.TrackQueue[1], Helpers.MusicTypes.ResumeQueue)

  Helpers:PrintToChat(pid, "Queue started/resumed!")
end

function MusicManager.AddToQueue(pid, cmd)
  if not MusicManager:PopulateCache(pid) then
    return
  end

  local song = Helpers:GetSongOnDemand(pid, cmd)

  if not song then
    return
  end

  table.insert(MusicManager.TrackQueue, song)

  local autoStart = not string.find(cmd[1], "nostart", 9)

  if autoStart and MusicManager.CurrentSongType == Helpers.MusicTypes.Stop then
    MusicManager.ResumeQueue(pid)
  end

  Helpers:PrintToChat(pid, string.format("Track \"%s\" has been added at position %d!", song, tableHelper.getCount(MusicManager.TrackQueue)))
end

function MusicManager.ViewQueue(pid)
  local str = "\n"

  for i, track in ipairs(MusicManager.TrackQueue) do
    str = str .. string.format("- %i: %s\n", i, track)
  end

  local leng = string.len(str)
  Helpers:PrintToChat(pid, string.sub(str, 1, leng - 1), _, _, "\n")
end

local songTypeBeforeLoop = nil

function MusicManager.Loop(pid)
  if MusicManager.CurrentSongType == Helpers.MusicTypes.Stop then
    return
  end

  local state = ""

  if MusicManager.CurrentSongType ~= Helpers.MusicTypes.Loop then
    songTypeBeforeLoop = MusicManager.CurrentSongType
    MusicManager.CurrentSongType = Helpers.MusicTypes.Loop

    state = "enabled"
  else
    MusicManager.CurrentSongType = songTypeBeforeLoop
    songTypeBeforeLoop = nil

    state = "disabled"
  end

  Helpers:PrintToChat(pid, string.format("Looping %s!", state), _, true)
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

function MusicManager.ReloadTracks(pid)
  MusicManager.CachedFiles = { }

  MusicManager:PopulateCache(pid, true)

  Helpers:PrintToChat(pid, string.format(
    "Tracks reloaded!\n%sPlease note: OpenMW only loads its data files between restarts; "
    .. "this command is only so that the server's list is up to date.", color.Warning), _, true, "\n")
end

local cmdList =
{
  "playtrack",
  "radiostart",
  "radiostop",
  "queueadd",
  "queueaddnostart",
  "queueplay",
  "queueresume",
  "queuelist",
  "loop",
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
customCommandHooks.registerCommand("radiostop",  MusicManager.RadioStop)

customCommandHooks.registerCommand("queueadd",        MusicManager.AddToQueue)
customCommandHooks.registerCommand("queueaddnostart", MusicManager.AddToQueue)
customCommandHooks.registerCommand("queueplay",       MusicManager.ResumeQueue)
customCommandHooks.registerCommand("queueresume",     MusicManager.ResumeQueue)
customCommandHooks.registerCommand("queuelist",       MusicManager.ViewQueue)

customCommandHooks.registerCommand("loop", MusicManager.Loop)
customCommandHooks.registerCommand("listtracks", MusicManager.ListTracks)
customCommandHooks.registerCommand("reloadtracks", MusicManager.ReloadTracks)